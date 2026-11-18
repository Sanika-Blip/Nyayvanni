import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/report_model.dart';
import '../services/api_service.dart';
import '../services/fir_parser.dart';

class ReportProvider extends ChangeNotifier {
  static const _storageKey = 'nyayvanni_fir_drafts';

  List<PoliceReport> _reports = [];
  PoliceReport? _currentReport;
  bool _isLoading = false;

  List<PoliceReport> get reports => _reports;
  PoliceReport? get currentReport => _currentReport;
  bool get isLoading => _isLoading;

  List<PoliceReport> get draftReports =>
      _reports.where((r) => r.status == ReportStatus.draft).toList();

  List<PoliceReport> get completedReports =>
      _reports.where((r) => r.status == ReportStatus.completed).toList();

  List<PoliceReport> get submittedReports =>
      _reports.where((r) => r.status == ReportStatus.submitted).toList();

  Future<void> loadDrafts() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (ApiService.token != null) {
        _reports = await ApiService.fetchDrafts();
        await _persist();
      } else {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_storageKey);
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List<dynamic>;
          _reports = list
              .map((e) => PoliceReport.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_storageKey);
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List<dynamic>;
          _reports = list
              .map((e) => PoliceReport.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      } catch (_) {
        _reports = [];
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_reports.map((r) => r.toJson()).toList()),
    );
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
    _persist();
  }

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
  }) {
    if (_currentReport == null) return;
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
    r.updatedAt = DateTime.now();
    notifyListeners();
    _persist();
  }

  Future<void> saveReport({ReportStatus status = ReportStatus.completed}) async {
    if (_currentReport == null) return;

    _currentReport!.status = status;
    _currentReport!.updatedAt = DateTime.now();

    final existing = _reports.indexWhere((r) => r.id == _currentReport!.id);
    if (existing >= 0) {
      _reports[existing] = _currentReport!;
    } else {
      _reports.insert(0, _currentReport!);
    }

    await _persist();
    await ApiService.upsertDraft(_currentReport!);
    notifyListeners();
  }

  Future<void> submitReport(String reportId) async {
    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx >= 0) {
      _reports[idx].status = ReportStatus.submitted;
      _reports[idx].updatedAt = DateTime.now();
      if (_currentReport?.id == reportId) {
        _currentReport!.status = ReportStatus.submitted;
      }
      await _persist();
      await ApiService.upsertDraft(_reports[idx]);
      notifyListeners();
    }
  }

  Future<void> deleteReport(String reportId) async {
    _reports.removeWhere((r) => r.id == reportId);
    if (_currentReport?.id == reportId) {
      _currentReport = null;
    }
    await _persist();
    await ApiService.deleteDraft(reportId);
    notifyListeners();
  }
}
