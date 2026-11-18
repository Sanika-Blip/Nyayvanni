import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/report_model.dart';
import '../models/report_provider.dart';
import '../widgets/common_widgets.dart';

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  bool _isGeneratingPdf = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        final report = provider.currentReport;
        if (report == null) {
          return const Scaffold(
            body: Center(child: Text('No report selected')),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: CustomScrollView(
            slivers: [
              _buildAppBar(context, report),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildReportHeader(report),
                      const SizedBox(height: 20),
                      _buildMetaCard(report),
                      const SizedBox(height: 20),
                      if (report.sections.isNotEmpty) ...[
                        _buildSectionsCard(report),
                        const SizedBox(height: 20),
                      ],
                      if (report.rawTranscript.isNotEmpty) ...[
                        _buildTranscriptCard(report),
                        const SizedBox(height: 20),
                      ],
                      _buildActionButtons(context, report),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context, PoliceReport report) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppTheme.background,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.arrow_back_ios_new,
              size: 16, color: AppTheme.textPrimary),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        report.reportNumber,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.share_outlined,
                  size: 18, color: AppTheme.textPrimary),
            ),
            onPressed: () => _shareReport(report),
          ),
        ),
      ],
    );
  }

  Widget _buildReportHeader(PoliceReport report) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.description_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FIR draft',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      report.reportNumber,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: report.status),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeaderInfoItem(
                icon: Icons.person_outline,
                label: 'Complainant',
                value: report.complainantName.isEmpty
                    ? 'Not extracted'
                    : report.complainantName,
              ),
              const SizedBox(width: 24),
              _HeaderInfoItem(
                icon: Icons.access_time,
                label: 'Date',
                value: DateFormat('dd MMM yyyy').format(report.createdAt),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _HeaderInfoItem(
                icon: Icons.location_city_outlined,
                label: 'Station',
                value: report.station,
              ),
            ],
          ),
          if (report.confidenceScore > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.insights, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text(
                  'AI Accuracy: ${(report.confidenceScore * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: report.confidenceScore,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaCard(PoliceReport report) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report Information',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetaItem(
                  label: 'Phone',
                  value: report.complainantPhone.isEmpty
                      ? '—'
                      : report.complainantPhone,
                  icon: Icons.phone_outlined,
                ),
              ),
              Expanded(
                child: _MetaItem(
                  label: 'District',
                  value: report.district,
                  icon: Icons.map_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetaItem(
                  label: 'Language',
                  value: report.language.name,
                  icon: Icons.language,
                ),
              ),
              Expanded(
                child: _MetaItem(
                  label: 'Last Updated',
                  value: DateFormat('dd/MM/yy HH:mm').format(report.updatedAt),
                  icon: Icons.update,
                ),
              ),
            ],
          ),
          if (report.summary.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.primaryLight.withOpacity(0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.summarize_outlined,
                      size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Summary',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report.summary,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionsCard(PoliceReport report) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Structured FIR draft',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome,
                            size: 12, color: AppTheme.success),
                        const SizedBox(width: 4),
                        Text(
                          'AI filled',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Edit any field before you export. This is a draft, not a filed FIR.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
              if (report.isLowConfidence) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Low transcription confidence (${(report.confidenceScore * 100).toInt()}%). Please check highlighted sections.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8A6D1B),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          ...report.sections.asMap().entries.map((entry) {
            final idx = entry.key;
            final section = entry.value;
            return _SectionBlock(
              index: idx + 1,
              section: section,
              isLast: idx == report.sections.length - 1,
              onChanged: (value) {
                context.read<ReportProvider>().updateSectionContent(idx, value);
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTranscriptCard(PoliceReport report) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Original Transcript',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              report.rawTranscript,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, PoliceReport report) {
    return Column(
      children: [
        // Generate PDF
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isGeneratingPdf ? null : () => _generatePdf(report),
            icon: _isGeneratingPdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf),
            label: Text(_isGeneratingPdf ? 'Generating PDF...' : 'Export as PDF'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Submit button
        if (report.status != ReportStatus.submitted)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _submitReport(context, report),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Finalise draft'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Print
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _printReport(report),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print draft'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: const BorderSide(color: AppTheme.divider),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  /// The default PDF fonts cannot draw Devanagari, so Hindi/Marathi text would
  /// come out blank. Load Noto fonts (Latin + Devanagari) instead.
  Future<pw.ThemeData> _pdfTheme() async {
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final devRegular = await PdfGoogleFonts.notoSansDevanagariRegular();
    final devBold = await PdfGoogleFonts.notoSansDevanagariBold();
    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      fontFallback: [devRegular, devBold],
    );
  }

  Future<void> _generatePdf(PoliceReport report) async {
    setState(() => _isGeneratingPdf = true);

    try {
      final theme = await _pdfTheme();
      final pdf = pw.Document(theme: theme);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => _buildPdfHeader(report),
          footer: (context) => _buildPdfFooter(context, report),
          build: (context) => [
            _buildPdfBody(report),
          ],
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${report.reportNumber}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (mounted) setState(() => _isGeneratingPdf = false);

      // Show preview
      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
          name: report.reportNumber,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Could not generate the PDF. Check your internet connection (fonts are downloaded on first use) and try again.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  pw.Widget _buildPdfHeader(PoliceReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blueGrey200, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'NyayVanni — FIR Draft (not an official filing)',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.blueGrey600,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'FIRST INFORMATION REPORT (DRAFT)',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                report.reportNumber,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.Text(
                DateFormat('dd MMMM yyyy, HH:mm').format(report.createdAt),
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.blueGrey500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context, PoliceReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.blueGrey200, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${report.station} • ${report.district}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey400),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey400),
          ),
          pw.Text(
            'Generated by NyayVanni — academic draft only',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey400),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfBody(PoliceReport report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 16),

        // Officer info table
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColors.blueGrey50,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('COMPLAINANT',
                        style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.blueGrey500,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                        report.complainantName.isEmpty
                            ? 'As per narration'
                            : report.complainantName,
                        style: pw.TextStyle(
                            fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                        report.complainantPhone.isEmpty
                            ? ''
                            : 'Phone: ${report.complainantPhone}',
                        style: pw.TextStyle(
                            fontSize: 10, color: PdfColors.blueGrey600)),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('STATION',
                        style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.blueGrey500,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(report.station,
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text(report.district,
                        style: pw.TextStyle(
                            fontSize: 10, color: PdfColors.blueGrey600)),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('LANGUAGE',
                        style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.blueGrey500,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(report.language.name,
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    if (report.confidenceScore > 0)
                      pw.Text(
                          'Accuracy: ${(report.confidenceScore * 100).toInt()}%',
                          style: pw.TextStyle(
                              fontSize: 10, color: PdfColors.green700)),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Sections
        if (report.sections.isNotEmpty) ...[
          pw.Text(
            'REPORT DETAILS',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.blueGrey500,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          pw.SizedBox(height: 10),
          ...report.sections.map((section) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      section.title.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                          color: PdfColors.blueGrey100, width: 1),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      section.content,
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.blueGrey800,
                        lineSpacing: 4,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 14),
                ],
              )),
        ],

        // Raw transcript
        if (report.rawTranscript.isNotEmpty) ...[
          pw.Text(
            'ORIGINAL SPEECH TRANSCRIPT',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.blueGrey500,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              report.rawTranscript,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.blueGrey600,
                fontStyle: pw.FontStyle.italic,
                lineSpacing: 4,
              ),
            ),
          ),
        ],

        pw.SizedBox(height: 30),

        // Signature section
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Container(height: 40),
                  pw.Divider(color: PdfColors.blueGrey300),
                  pw.SizedBox(height: 4),
                  pw.Text('Complainant',
                      style: pw.TextStyle(
                          fontSize: 9, color: PdfColors.blueGrey500)),
                  pw.Text(
                      report.complainantName.isEmpty
                          ? ' '
                          : report.complainantName,
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(width: 40),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Container(height: 40),
                  pw.Divider(color: PdfColors.blueGrey300),
                  pw.SizedBox(height: 4),
                  pw.Text('Duty officer',
                      style: pw.TextStyle(
                          fontSize: 9, color: PdfColors.blueGrey500)),
                  pw.Text('Review & file (manual)',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _printReport(PoliceReport report) async {
    final pdf = pw.Document(theme: await _pdfTheme());
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildPdfHeader(report),
        footer: (context) => _buildPdfFooter(context, report),
        build: (context) => [_buildPdfBody(report)],
      ),
    );
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: report.reportNumber,
    );
  }

  Future<void> _shareReport(PoliceReport report) async {
    final text = StringBuffer();
    text.writeln('NyayVanni FIR draft — ${report.reportNumber}');
    text.writeln('This is not an officially filed FIR.');
    text.writeln('Complainant: ${report.complainantName}');
    text.writeln('Station: ${report.station}');
    text.writeln('');
    for (final section in report.sections) {
      text.writeln('${section.title}:');
      text.writeln(section.content);
      text.writeln('');
    }
    await Share.share(text.toString(), subject: report.reportNumber);
  }

  void _submitReport(BuildContext context, PoliceReport report) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          'Finalise this draft?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This marks the draft as ready for a duty officer to review. It does not file an FIR with the police or CCTNS.',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ReportProvider>().submitReport(report.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Draft finalised for review',
                      style: GoogleFonts.inter()),
                  backgroundColor: AppTheme.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            child: Text('Finalise', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _HeaderInfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeaderInfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white60, size: 13),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white60,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetaItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionBlock extends StatefulWidget {
  final int index;
  final ReportSection section;
  final bool isLast;
  final ValueChanged<String>? onChanged;

  const _SectionBlock({
    required this.index,
    required this.section,
    required this.isLast,
    this.onChanged,
  });

  @override
  State<_SectionBlock> createState() => _SectionBlockState();
}

class _SectionBlockState extends State<_SectionBlock> {
  bool _isExpanded = true;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.section.content);
  }

  @override
  void didUpdateWidget(covariant _SectionBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section.content != widget.section.content &&
        _controller.text != widget.section.content) {
      _controller.text = widget.section.content;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: widget.section.lowConfidence
                      ? AppTheme.warning.withOpacity(0.25)
                      : AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${widget.index}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.section.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: AppTheme.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
        if (_isExpanded) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.section.lowConfidence
                  ? AppTheme.warning.withOpacity(0.12)
                  : AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
              border: widget.section.lowConfidence
                  ? Border.all(color: AppTheme.warning.withOpacity(0.6))
                  : null,
            ),
            child: TextField(
              controller: _controller,
              maxLines: null,
              onChanged: widget.onChanged,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
        if (!widget.isLast) ...[
          const SizedBox(height: 12),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}