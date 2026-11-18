import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/report_model.dart';
import '../models/report_provider.dart';
import '../services/api_service.dart';
import '../services/fir_pdf.dart';
import '../widgets/common_widgets.dart';

/// FIR draft editor. Also used read-only by supervisors ([reviewMode]) who
/// approve the FIR or return it with a comment.
class ReportDetailScreen extends StatefulWidget {
  final bool reviewMode;
  const ReportDetailScreen({super.key, this.reviewMode = false});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  static const _offences = <String>[
    'Theft / चोरी',
    'Robbery / डकैती',
    'Assault / मारपीट',
    'Cheating / ठगी',
    'Harassment / छेड़छाड़',
    'Accident / अपघात',
    'Missing person / गुमशुदगी',
    'Criminal intimidation / धमकी',
  ];

  bool _busy = false;
  bool _working = false;

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _date;
  late final TextEditingController _time;
  late final TextEditingController _place;
  late final TextEditingController _offence;
  late final TextEditingController _accused;
  late final TextEditingController _narration;

  @override
  void initState() {
    super.initState();
    final r = context.read<ReportProvider>().currentReport;
    _name = TextEditingController(text: r?.complainantName ?? '');
    _phone = TextEditingController(text: r?.complainantPhone ?? '');
    _address = TextEditingController(text: r?.complainantAddress ?? '');
    _date = TextEditingController(text: r?.occurrenceDate ?? '');
    _time = TextEditingController(text: r?.occurrenceTime ?? '');
    _place = TextEditingController(text: r?.placeOfOccurrence ?? '');
    _offence = TextEditingController(text: r?.natureOfOffence ?? '');
    _accused = TextEditingController(text: r?.accusedDetails ?? '');
    _narration = TextEditingController(text: r?.rawTranscript ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _name, _phone, _address, _date, _time, _place, _offence, _accused,
      _narration,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppTheme.error : AppTheme.success,
      ),
    );
  }

  ReportProvider get _provider => context.read<ReportProvider>();

  // ── Checks shown before sending ───────────────────────────────────────────

  List<(String, bool, String)> _checks(PoliceReport r) {
    final phoneDigits = r.complainantPhone.replaceAll(RegExp(r'\D'), '');
    return [
      (
        'Complainant name',
        r.complainantName.trim().isNotEmpty,
        'Enter the complainant’s name.'
      ),
      (
        'Date of occurrence',
        r.occurrenceDate.trim().isNotEmpty,
        'The date was not found in the statement. Please enter it.'
      ),
      (
        'Place of occurrence',
        r.placeOfOccurrence.trim().isNotEmpty,
        'The place was not found in the statement. Please enter it.'
      ),
      (
        'Nature of offence',
        r.natureOfOffence.trim().isNotEmpty &&
            !r.natureOfOffence.startsWith('Cognisable offence'),
        'The offence could not be classified. Choose or type one.'
      ),
      (
        'Narration',
        r.rawTranscript.trim().isNotEmpty,
        'The brief facts are empty.'
      ),
      (
        'Phone number',
        r.complainantPhone.trim().isEmpty || phoneDigits.length >= 10,
        'The phone number looks incomplete.'
      ),
      (
        'Speech recognition',
        !r.isLowConfidence,
        'Speech recognition was uncertain. Read the narration carefully.'
      ),
    ];
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _sendForReview(PoliceReport r) async {
    final problems = _checks(r).where((c) => !c.$2).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send for review?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your station supervisor will review this FIR. You cannot edit it while it is in review.',
            ),
            if (problems.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Still to check:',
                  style: GoogleFonts.notoSans(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              for (final p in problems)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('•  ${p.$1}'),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go back'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(problems.isEmpty ? 'Send' : 'Send anyway'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _working = true);
    try {
      await _provider.submitForReview(r.id);
      _toast('Sent to your supervisor for review.');
    } catch (e) {
      _toast(ApiService.describe(e), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _approve(PoliceReport r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve this FIR?'),
        content: const Text(
            'The FIR will be locked. The officer can no longer edit it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Approve')),
        ],
      ),
    );
    if (ok != true) return;
    await _decide(r, 'approved', '');
  }

  Future<void> _returnToOfficer(PoliceReport r) async {
    final ctrl = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Return for correction'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Explain what the officer needs to correct',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('Return'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (comment == null) return;
    await _decide(r, 'returned', comment);
  }

  Future<void> _decide(PoliceReport r, String decision, String comment) async {
    setState(() => _working = true);
    try {
      await _provider.reviewDecision(r, decision: decision, comment: comment);
      _toast(decision == 'approved'
          ? 'FIR approved.'
          : 'Returned to the officer.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _toast(ApiService.describe(e), error: true);
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _exportPdf(PoliceReport r, {bool share = false}) async {
    setState(() => _busy = true);
    try {
      final doc = await FirPdf.build(r);
      if (share) {
        await Printing.sharePdf(
          bytes: await doc.save(),
          filename: '${r.reportNumber}.pdf',
        );
      } else {
        await Printing.layoutPdf(
          onLayout: (_) => doc.save(),
          name: r.reportNumber,
        );
      }
    } catch (_) {
      _toast(
        'Could not create the PDF. Fonts are downloaded the first time, so check your internet connection and try again.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();
    final report = provider.currentReport;
    if (report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('FIR draft')),
        body: const Center(child: Text('No report selected')),
      );
    }
    final readOnly = widget.reviewMode || report.isLocked;
    final gutter = contentGutter(context, maxWidth: 760);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(report.reportNumber),
        actions: [
          IconButton(
            tooltip: 'Share as PDF',
            onPressed: _busy ? null : () => _exportPdf(report, share: true),
            icon: const Icon(Icons.ios_share, size: 20),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 40),
        children: [
          _banner(report),
          _summaryCard(report, provider.isUnsynced(report.id)),
          const SizedBox(height: 16),
          if (!readOnly) ...[
            _checklist(report),
            const SizedBox(height: 16),
          ],
          _detailsPanel(report, readOnly),
          const SizedBox(height: 16),
          _narrationPanel(readOnly),
          const SizedBox(height: 20),
          _actions(report),
        ],
      ),
    );
  }

  Widget _banner(PoliceReport r) {
    Color color;
    IconData icon;
    String title;
    String body;
    if (widget.reviewMode) {
      color = AppTheme.secondary;
      icon = Icons.fact_check_outlined;
      title = 'Review this FIR';
      body =
          'Submitted by ${r.officerName.isEmpty ? r.officerId : r.officerName}. Read the details, then approve or return it with a comment.';
    } else if (r.isReturned) {
      color = AppTheme.error;
      icon = Icons.reply_outlined;
      title = 'Returned for correction';
      body =
          '${r.reviewComment}${r.reviewedBy.isEmpty ? '' : '\n— ${r.reviewedBy}'}';
    } else if (r.isPending) {
      color = AppTheme.secondary;
      icon = Icons.hourglass_top_outlined;
      title = 'Sent for review';
      body = 'Editing is locked until your supervisor decides.';
    } else if (r.isApproved) {
      color = AppTheme.success;
      icon = Icons.verified_outlined;
      title = 'Approved';
      body =
          '${r.reviewedBy.isEmpty ? 'Approved by your supervisor.' : 'Approved by ${r.reviewedBy}.'} This FIR is locked.';
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.notoSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const SizedBox(height: 2),
                Text(body,
                    style: GoogleFonts.notoSans(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                        height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(PoliceReport r, bool unsynced) {
    Widget item(String label, String value) => Padding(
          padding: const EdgeInsets.only(right: 28, top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: GoogleFonts.notoSans(
                      fontSize: 11, color: Colors.white60)),
              Text(value.isEmpty ? '—' : value,
                  style: GoogleFonts.notoSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ],
          ),
        );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: const BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.all(Radius.circular(4)),
        border: Border(bottom: BorderSide(color: AppTheme.accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.reportNumber,
                  style: GoogleFonts.notoSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              ReportStatusBadge(report: r),
            ],
          ),
          Wrap(
            children: [
              item('Station', r.station),
              item('District', r.district),
              item('Recorded by',
                  [r.officerRank, r.officerName].where((s) => s.isNotEmpty).join(' ')),
              item('Created', DateFormat('dd MMM yyyy, HH:mm').format(r.createdAt)),
              if (r.confidenceScore > 0)
                item('Speech confidence',
                    '${(r.confidenceScore * 100).round()}%'),
            ],
          ),
          if (unsynced) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.cloud_off_outlined,
                    size: 14, color: AppTheme.accentLight),
                SizedBox(width: 6),
                Text(
                  'Changes saved on this device. They will upload when you are online.',
                  style: TextStyle(fontSize: 12, color: AppTheme.accentLight),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _checklist(PoliceReport r) {
    final checks = _checks(r);
    final open = checks.where((c) => !c.$2).toList();
    return FormPanel(
      title: 'Check before sending',
      subtitle: open.isEmpty
          ? 'Everything required is filled in.'
          : '${open.length} item${open.length == 1 ? '' : 's'} need your attention.',
      child: open.isEmpty
          ? Row(
              children: [
                const Icon(Icons.check_circle,
                    size: 18, color: AppTheme.success),
                const SizedBox(width: 8),
                Text('Ready to send for review.',
                    style: GoogleFonts.notoSans(fontSize: 13)),
              ],
            )
          : Column(
              children: [
                for (final c in open)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 18, color: AppTheme.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${c.$1}. ',
                                  style: GoogleFonts.notoSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700),
                                ),
                                TextSpan(
                                  text: c.$3,
                                  style: GoogleFonts.notoSans(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _detailsPanel(PoliceReport r, bool readOnly) {
    final wide = MediaQuery.of(context).size.width >= 640;
    Widget pair(Widget a, Widget b) => wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: 14),
              Expanded(child: b),
            ],
          )
        : Column(children: [a, const SizedBox(height: 14), b]);

    return FormPanel(
      title: 'FIR details',
      subtitle: readOnly
          ? 'Read only'
          : 'Details are filled from the statement. Correct anything that is wrong.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NyayaTextField(
            label: 'Complainant name',
            controller: _name,
            readOnly: readOnly,
            onChanged: (v) => _provider.updateDraftFields(complainantName: v),
          ),
          const SizedBox(height: 14),
          pair(
            NyayaTextField(
              label: 'Phone number',
              controller: _phone,
              readOnly: readOnly,
              keyboardType: TextInputType.phone,
              onChanged: (v) =>
                  _provider.updateDraftFields(complainantPhone: v),
            ),
            NyayaTextField(
              label: 'Address',
              controller: _address,
              readOnly: readOnly,
              onChanged: (v) =>
                  _provider.updateDraftFields(complainantAddress: v),
            ),
          ),
          const SizedBox(height: 14),
          pair(
            NyayaTextField(
              label: 'Date of occurrence',
              controller: _date,
              readOnly: readOnly,
              onChanged: (v) => _provider.updateDraftFields(occurrenceDate: v),
            ),
            NyayaTextField(
              label: 'Time of occurrence',
              controller: _time,
              readOnly: readOnly,
              onChanged: (v) => _provider.updateDraftFields(occurrenceTime: v),
            ),
          ),
          const SizedBox(height: 14),
          NyayaTextField(
            label: 'Place of occurrence',
            controller: _place,
            readOnly: readOnly,
            onChanged: (v) =>
                _provider.updateDraftFields(placeOfOccurrence: v),
          ),
          const SizedBox(height: 14),
          NyayaTextField(
            label: 'Nature of offence',
            controller: _offence,
            readOnly: readOnly,
            onChanged: (v) => _provider.updateDraftFields(natureOfOffence: v),
          ),
          if (!readOnly) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 0,
              children: [
                for (final o in _offences)
                  ActionChip(
                    label: Text(o, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.divider),
                    onPressed: () {
                      _offence.text = o;
                      _provider.updateDraftFields(natureOfOffence: o);
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          NyayaTextField(
            label: 'Particulars of accused (if known)',
            controller: _accused,
            readOnly: readOnly,
            onChanged: (v) => _provider.updateDraftFields(accusedDetails: v),
          ),
          const SizedBox(height: 14),
          Text('Language of statement',
              style: GoogleFonts.notoSans(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<Language>(
            value: r.language,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: readOnly ? const Color(0xFFF3F5F8) : Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: [
              for (final l in Language.values)
                DropdownMenuItem(
                  value: l,
                  child: Text('${l.name}  (${l.nativeName})'),
                ),
            ],
            onChanged: readOnly
                ? null
                : (l) {
                    if (l != null) _provider.updateDraftFields(language: l);
                  },
          ),
        ],
      ),
    );
  }

  Widget _narrationPanel(bool readOnly) {
    return FormPanel(
      title: 'Brief facts of the case',
      subtitle: readOnly
          ? 'Read only'
          : 'The complainant’s statement. Edit to correct recognition errors.',
      child: NyayaTextField(
        label: 'Narration',
        controller: _narration,
        readOnly: readOnly,
        minLines: 6,
        maxLines: 14,
        onChanged: (v) => _provider.updateDraftFields(narration: v),
      ),
    );
  }

  Widget _actions(PoliceReport r) {
    final pdfButtons = Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _exportPdf(r),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text(_busy ? 'Preparing…' : 'Preview / print PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
      ],
    );

    if (widget.reviewMode) {
      return Column(
        children: [
          pdfButtons,
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _working ? null : () => _returnToOfficer(r),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Return with comment'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _working ? null : () => _approve(r),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success),
                  child: Text(_working ? 'Please wait…' : 'Approve'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        if (!r.isLocked) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _working ? null : () => _sendForReview(r),
              icon: const Icon(Icons.send_outlined, size: 18),
              label: Text(_working ? 'Sending…' : 'Send for review'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        pdfButtons,
      ],
    );
  }
}
