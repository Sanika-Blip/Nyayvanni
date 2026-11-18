import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/report_model.dart';
import '../services/api_service.dart';
import '../services/fir_parser.dart';

class ReportProvider extends ChangeNotifier {
  static const _storageKey = 'nyayvanni_fir_drafts';
  static const _pendingDeletesKey = 'nyayvanni_pending_deletes';
  static const _unsyncedKey = 'nyayvanni_unsynced';

  List<PoliceReport> _reports = [];
  List<PoliceReport> _queue = [];
  PoliceReport? _currentReport;
  bool _isLoading = false;
  Timer? _syncTimer;
  final Set<String> _unsynced = {};

  List<PoliceReport> get reports => _reports;
  List<PoliceReport> get reviewQueue => _queue;
  PoliceReport? get currentReport => _currentReport;
  bool get isLoading => _isLoading;

  /// True when this report has changes the server has not confirmed yet.
  bool isUnsynced(String id) => _unsynced.contains(id);

  List<PoliceReport> get draftReports => _reports
      .where((r) => !r.isLocked)
      .toList(); // drafts, including ones returned for correction

  List<PoliceReport> get pendingReports =>
      _reports.where((r) => r.isPending).toList();

  List<PoliceReport> get approvedReports =>
      _reports.where((r) => r.isApproved).toList();

  Future<List<PoliceReport>> _readLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      _unsynced
        ..clear()
        ..addAll(prefs.getStringList(_unsyncedKey) ?? const []);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PoliceReport.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Set<String>> _readPendingDeletes() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_pendingDeletesKey) ?? []).toSet();
  }

  Future<void> _writePendingDeletes(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pendingDeletesKey, ids.toList());
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_reports.map((r) => r.toJson()).toList()),
    );
    await prefs.setStringList(_unsyncedKey, _unsynced.toList());
  }

  /// Uploads one report and records whether the server confirmed it.
  Future<bool> _upload(PoliceReport r) async {
    final ok = await ApiService.upsertDraft(r);
    if (ok) {
      _unsynced.remove(r.id);
    } else {
      _unsynced.add(r.id);
    }
    await _persist();
    notifyListeners();
    return ok;
  }

  /// Loads reports from the server and merges them with anything saved on this
  /// device. Reports created or edited offline are kept and uploaded, never
  /// overwritten by an older server copy.
  Future<void> loadDrafts() async {
    _isLoading = true;
    notifyListeners();

    final local = _reports.isNotEmpty ? [..._reports] : await _readLocal();

    if (ApiService.token == null) {
      _reports = local;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      // Finish deletions that could not reach the server earlier.
      final pending = await _readPendingDeletes();
      for (final id in pending.toList()) {
        if (await ApiService.deleteDraft(id)) pending.remove(id);
      }
      await _writePendingDeletes(pending);

      final server = await ApiService.fetchDrafts();
      final byId = <String, PoliceReport>{
        for (final r in server)
          if (!pending.contains(r.id)) r.id: r,
      };
      final toUpload = <PoliceReport>[];
      for (final l in local) {
        if (pending.contains(l.id)) continue;
        final s = byId[l.id];
        if (s == null) {
          byId[l.id] = l;
          toUpload.add(l);
        } else if (l.updatedAt.isAfter(s.updatedAt) && !s.isLocked) {
          // Local edits are newer. A report that is with the reviewer is
          // owned by the server copy, so it is never overwritten.
          byId[l.id] = l;
          toUpload.add(l);
        } else {
          _unsynced.remove(l.id);
        }
      }
      _reports = byId.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      await _persist();
      for (final r in toUpload) {
        await _upload(r);
      }
    } catch (_) {
      // Offline or server error: keep what is on the device.
      _reports = local;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Supervisors: FIRs from the same station waiting for a decision.
  Future<void> loadReviewQueue() async {
    try {
      _queue = await ApiService.fetchReviewQueue();
    } catch (_) {
      // keep the last known queue
    }
    notifyListeners();
  }

  /// Approves or returns a FIR. Throws [ApiException] with a readable message.
  Future<void> reviewDecision(
    PoliceReport report, {
    required String decision,
    String comment = '',
  }) async {
    await ApiService.reviewDraft(report.id,
        decision: decision, comment: comment);
    _queue.removeWhere((r) => r.id == report.id);
    if (_currentReport?.id == report.id) _currentReport = null;
    notifyListeners();
  }

  /// Clears everything held for the signed-in officer (called on sign-out so
  /// the next officer on this device never sees these reports).
  Future<void> clear() async {
    _syncTimer?.cancel();
    _reports = [];
    _queue = [];
    _unsynced.clear();
    _currentReport = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_pendingDeletesKey);
    await prefs.remove(_unsyncedKey);
    notifyListeners();
  }

  /// Uploads edits shortly after the officer stops typing.
  void _scheduleSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 800), () {
      final r = _currentReport;
      if (r != null && _reports.any((x) => x.id == r.id)) {
        _upload(r);
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  void createNewReport({
    required Language language,
    required String complainantName,
    required String complainantPhone,
    required String complainantAddress,
    required String station,
    required String district,
    String officerId = '',
    String officerName = '',
    String officerRank = '',
    String badgeNumber = '',
  }) {
    _currentReport = PoliceReport(
      language: language,
      complainantName: complainantName,
      complainantPhone: complainantPhone,
      complainantAddress: complainantAddress,
      station: station,
      district: district,
      officerId: officerId,
      officerName: officerName,
      officerRank: officerRank,
      badgeNumber: badgeNumber,
    );
    notifyListeners();
  }

  void setCurrentReport(PoliceReport report) {
    _currentReport = report;
    notifyListeners();
  }

  void updateTranscript(String transcript, double confidence) {
    if (_currentReport == null) return;
    _currentReport!.rawTranscript = transcript;
    _currentReport!.confidenceScore = confidence;
    _currentReport!.updatedAt = DateTime.now();
    notifyListeners();
  }

  Future<void> generateStructuredReport(String transcript) async {
    if (_currentReport == null) return;

    final fields = await ApiService.parseTranscript(
      transcript: transcript,
      language: _currentReport!.language,
    );

    if (_currentReport!.language == Language.auto) {
      _currentReport!.language = FirParser.detectLanguage(transcript);
    }

    if (_currentReport!.complainantName.trim().isEmpty &&
        fields.complainantName.isNotEmpty) {
      _currentReport!.complainantName = fields.complainantName;
    }
    _currentReport!.occurrenceDate = fields.occurrenceDate;
    _currentReport!.occurrenceTime = fields.occurrenceTime;
    _currentReport!.placeOfOccurrence = fields.placeOfOccurrence;
    _currentReport!.natureOfOffence = fields.natureOfOffence;
    _currentReport!.accusedDetails = fields.accusedDetails;
    _currentReport!.summary = fields.summary;
    _currentReport!.sections = FirParser.toSections(
      fields,
      draft: _currentReport!,
    );
    _currentReport!.updatedAt = DateTime.now();
    notifyListeners();
  }

  void updateSectionContent(int index, String content) {
    if (_currentReport == null) return;
    if (index < 0 || index >= _currentReport!.sections.length) return;
    _currentReport!.sections[index].content = content;
    _currentReport!.updatedAt = DateTime.now();
    notifyListeners();
    _markChanged();
  }

  /// Edits one or more FIR fields. The text sections are rebuilt from the
  /// fields so the form, PDF and server copy always agree.
  void updateDraftFields({
    String? complainantName,
    String? complainantPhone,
    String? complainantAddress,
    String? station,
    String? district,
    String? occurrenceDate,
    String? occurrenceTime,
    String? placeOfOccurrence,
    String? natureOfOffence,
    String? accusedDetails,
    String? narration,
    Language? language,
  }) {
    if (_currentReport == null || _currentReport!.isLocked) return;
    final r = _currentReport!;
    if (complainantName != null) r.complainantName = complainantName;
    if (complainantPhone != null) r.complainantPhone = complainantPhone;
    if (complainantAddress != null) r.complainantAddress = complainantAddress;
    if (station != null) r.station = station;
    if (district != null) r.district = district;
    if (occurrenceDate != null) r.occurrenceDate = occurrenceDate;
    if (occurrenceTime != null) r.occurrenceTime = occurrenceTime;
    if (placeOfOccurrence != null) r.placeOfOccurrence = placeOfOccurrence;
    if (natureOfOffence != null) r.natureOfOffence = natureOfOffence;
    if (accusedDetails != null) r.accusedDetails = accusedDetails;
    if (language != null) r.language = language;
    if (narration != null) {
      r.rawTranscript = narration;
      r.summary = FirParser.summarise(narration);
    }
    r.sections = FirParser.toSections(
      ParsedFirFields(
        complainantName: r.complainantName,
        occurrenceDate: r.occurrenceDate,
        occurrenceTime: r.occurrenceTime,
        placeOfOccurrence: r.placeOfOccurrence,
        natureOfOffence: r.natureOfOffence,
        accusedDetails: r.accusedDetails,
        incidentDescription: r.rawTranscript,
        summary: r.summary,
      ),
      draft: r,
    );
    r.updatedAt = DateTime.now();
    notifyListeners();
    _markChanged();
  }

  void _markChanged() {
    final r = _currentReport;
    if (r != null && _reports.any((x) => x.id == r.id)) {
      _unsynced.add(r.id);
    }
    _persist();
    _scheduleSync();
  }

  Future<void> saveReport({ReportStatus status = ReportStatus.draft}) async {
    if (_currentReport == null) return;

    _currentReport!.status = status;
    _currentReport!.updatedAt = DateTime.now();

    final existing = _reports.indexWhere((r) => r.id == _currentReport!.id);
    if (existing >= 0) {
      _reports[existing] = _currentReport!;
    } else {
      _reports.insert(0, _currentReport!);
    }

    _unsynced.add(_currentReport!.id);
    await _persist();
    notifyListeners();
    // A failed upload is retried automatically the next time drafts load.
    await _upload(_currentReport!);
  }

  /// Sends the current draft to the station supervisor for review.
  /// Throws [ApiException] with a readable message on failure.
  Future<void> submitForReview(String reportId) async {
    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx < 0) return;
    // Make sure the server has the latest version first.
    _syncTimer?.cancel();
    final ok = await _upload(_reports[idx]);
    if (!ok) {
      throw ApiException(
        'Could not reach the server. Connect to the network and try again.',
      );
    }
    final updated = await ApiService.submitDraft(reportId);
    _reports[idx] = updated;
    if (_currentReport?.id == reportId) _currentReport = updated;
    _unsynced.remove(reportId);
    await _persist();
    notifyListeners();
  }

  Future<void> deleteReport(String reportId) async {
    final target = _reports.where((r) => r.id == reportId).firstOrNull;
    if (target != null && target.isLocked) return;
    _reports.removeWhere((r) => r.id == reportId);
    _unsynced.remove(reportId);
    if (_currentReport?.id == reportId) {
      _currentReport = null;
    }
    await _persist();
    notifyListeners();
    final deleted = await ApiService.deleteDraft(reportId);
    if (!deleted && ApiService.token != null) {
      // Remember the delete so it is retried and the draft does not reappear.
      final pending = await _readPendingDeletes();
      pending.add(reportId);
      await _writePendingDeletes(pending);
    }
  }
}
