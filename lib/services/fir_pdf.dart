import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/report_model.dart';

/// Builds the printable FIR draft in a numbered, form-style layout with a QR
/// reference and signature blocks.
class FirPdf {
  static const _navy = PdfColor.fromInt(0xFF14283F);
  static const _line = PdfColor.fromInt(0xFF9AA5B1);
  static const _labelBg = PdfColor.fromInt(0xFFF1F3F6);
  static const _muted = PdfColor.fromInt(0xFF5B6678);

  /// The default PDF fonts cannot draw Devanagari, so Hindi/Marathi text would
  /// come out blank. Noto fonts (Latin + Devanagari) are used instead.
  static Future<pw.ThemeData> _theme() async {
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

  static String _or(String v, [String empty = 'Not stated']) =>
      v.trim().isEmpty ? empty : v.trim();

  static Future<pw.Document> build(PoliceReport r) async {
    final doc = pw.Document(
      theme: await _theme(),
      title: 'FIR draft ${r.reportNumber}',
      author: r.officerName,
    );
    final stamp = DateFormat('dd MMM yyyy, HH:mm');

    pw.Widget label(String t) => pw.Container(
          color: _labelBg,
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(t,
              style:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        );
    pw.Widget value(String t) => pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(t, style: const pw.TextStyle(fontSize: 10)),
        );
    pw.Widget num(int n) => pw.Container(
          color: _labelBg,
          padding: const pw.EdgeInsets.all(6),
          alignment: pw.Alignment.topCenter,
          child: pw.Text('$n', style: const pw.TextStyle(fontSize: 9)),
        );

    final officer = [
      if (r.officerRank.isNotEmpty) r.officerRank,
      _or(r.officerName, 'Recording officer'),
    ].join(' ');
    final officerIds = [
      if (r.badgeNumber.isNotEmpty) 'Badge no. ${r.badgeNumber}',
      if (r.officerId.isNotEmpty) 'ID ${r.officerId}',
    ].join(', ');

    final complainant = [
      _or(r.complainantName, 'As per narration'),
      if (r.complainantPhone.isNotEmpty) 'Phone: ${r.complainantPhone}',
      if (r.complainantAddress.isNotEmpty) 'Address: ${r.complainantAddress}',
    ].join('\n');

    final review = switch (r.reviewStatus) {
      'approved' =>
        'Approved by ${_or(r.reviewedBy)}${r.reviewedAt != null ? ' on ${stamp.format(r.reviewedAt!)}' : ''}',
      'pending' => 'Sent for review — awaiting supervisor decision',
      'returned' => 'Returned for correction: ${_or(r.reviewComment)}',
      _ => 'Draft — not yet sent for review',
    };

    final rows = <(String, String)>[
      ('District and police station', '${_or(r.district)}  /  ${_or(r.station)}'),
      ('Draft number and date', '${r.reportNumber}\n${stamp.format(r.createdAt)}'),
      ('Date and time of occurrence',
          'Date: ${_or(r.occurrenceDate)}\nTime: ${_or(r.occurrenceTime)}'),
      ('Place of occurrence', _or(r.placeOfOccurrence)),
      ('Complainant / informant', complainant),
      ('Nature of offence', _or(r.natureOfOffence)),
      ('Particulars of accused (if known)', _or(r.accusedDetails)),
      ('Brief facts of the case',
          _or(r.rawTranscript.isNotEmpty ? r.rawTranscript : r.summary,
              'No narration recorded')),
      ('Language of statement',
          '${r.language.name}${r.confidenceScore > 0 ? '   (speech confidence ${(r.confidenceScore * 100).round()}%)' : ''}'),
      ('Recorded by', '$officer${officerIds.isEmpty ? '' : '\n$officerIds'}'),
      ('Review status', review),
    ];

    pw.Widget signature(String caption, {String? name}) => pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 42),
              pw.Container(height: 0.8, color: _navy),
              pw.SizedBox(height: 4),
              pw.Text(caption, style: const pw.TextStyle(fontSize: 9)),
              if (name != null)
                pw.Text(name,
                    style: const pw.TextStyle(fontSize: 8, color: _muted)),
            ],
          ),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 36),
        header: (ctx) => ctx.pageNumber > 1
            ? pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text('FIR draft ${r.reportNumber} (continued)',
                    style: const pw.TextStyle(fontSize: 9, color: _muted)),
              )
            : pw.SizedBox(),
        footer: (ctx) => pw.Column(
          children: [
            pw.Container(height: 0.5, color: _line),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Prepared with NyayVanni as a draft for review. It is not a registered FIR.',
                  style: const pw.TextStyle(fontSize: 8, color: _muted),
                ),
                pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8, color: _muted)),
              ],
            ),
          ],
        ),
        build: (ctx) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FIRST INFORMATION REPORT',
                        style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: _navy)),
                    pw.SizedBox(height: 2),
                    pw.Text('Draft for review',
                        style:
                            const pw.TextStyle(fontSize: 10, color: _muted)),
                    pw.SizedBox(height: 6),
                    pw.Text(_or(r.station, 'Police station'),
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.Column(
                children: [
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'NYAYVANNI|${r.reportNumber}|${r.id}',
                    width: 60,
                    height: 60,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(r.reportNumber,
                      style: const pw.TextStyle(fontSize: 7, color: _muted)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(height: 2, color: _navy),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: _line, width: 0.6),
            columnWidths: {
              0: const pw.FixedColumnWidth(24),
              1: const pw.FixedColumnWidth(140),
              2: const pw.FlexColumnWidth(),
            },
            children: [
              for (var i = 0; i < rows.length; i++)
                pw.TableRow(
                  children: [num(i + 1), label(rows[i].$1), value(rows[i].$2)],
                ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              signature('Signature / thumb impression of complainant',
                  name: r.complainantName.isEmpty ? null : r.complainantName),
              pw.SizedBox(width: 28),
              signature('Signature of recording officer',
                  name: r.officerName.isEmpty ? null : r.officerName),
              if (r.isApproved) ...[
                pw.SizedBox(width: 28),
                signature('Reviewed and approved by',
                    name: r.reviewedBy.isEmpty ? null : r.reviewedBy),
              ],
            ],
          ),
        ],
      ),
    );
    return doc;
  }
}
