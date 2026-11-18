import '../models/report_model.dart';

class ParsedFirFields {
  final String complainantName;
  final String occurrenceDate;
  final String occurrenceTime;
  final String placeOfOccurrence;
  final String natureOfOffence;
  final String accusedDetails;
  final String incidentDescription;
  final String summary;

  const ParsedFirFields({
    this.complainantName = '',
    this.occurrenceDate = '',
    this.occurrenceTime = '',
    this.placeOfOccurrence = '',
    this.natureOfOffence = '',
    this.accusedDetails = '',
    this.incidentDescription = '',
    this.summary = '',
  });

  factory ParsedFirFields.fromJson(Map<String, dynamic> json) {
    return ParsedFirFields(
      complainantName: json['complainantName'] as String? ?? '',
      occurrenceDate: json['occurrenceDate'] as String? ?? '',
      occurrenceTime: json['occurrenceTime'] as String? ?? '',
      placeOfOccurrence: json['placeOfOccurrence'] as String? ?? '',
      natureOfOffence: json['natureOfOffence'] as String? ?? '',
      accusedDetails: json['accusedDetails'] as String? ?? '',
      incidentDescription: json['incidentDescription'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
    );
  }
}

/// Rule-based multilingual extraction for Hindi, Marathi, and English (BR-04).
class FirParser {
  static ParsedFirFields parse(String transcript, {Language? language}) {
    final text = transcript.trim();
    if (text.isEmpty) {
      return const ParsedFirFields();
    }

    return ParsedFirFields(
      complainantName: _extractName(text),
      occurrenceDate: _extractDate(text),
      occurrenceTime: _extractTime(text),
      placeOfOccurrence: _extractLocation(text),
      natureOfOffence: _extractOffence(text),
      accusedDetails: _extractAccused(text),
      incidentDescription: text,
      summary: _summarise(text),
    );
  }

  static Language detectLanguage(String text) {
    final hasDevanagari = RegExp(r'[\u0900-\u097F]').hasMatch(text);
    if (!hasDevanagari) return Language.english;
    if (RegExp(r'(आहे|माझे|मी |येथे|इथे|झाली)').hasMatch(text)) {
      return Language.marathi;
    }
    return Language.hindi;
  }

  static String _extractName(String text) {
    final patterns = <RegExp>[
      RegExp(
        r"(?:my name is|i am|i am called|this is)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,3})",
        caseSensitive: false,
      ),
      RegExp(r'(?:complainant|informant)\s+(?:is|:)\s+([A-Za-z][A-Za-z\s]{1,40})',
          caseSensitive: false),
      RegExp(r'मेरा नाम\s+([^\s,।.]{2,}(?:\s+[^\s,।.]{2,}){0,3})'),
      RegExp(r'मैं\s+([^\s,।.]{2,}(?:\s+[^\s,।.]{2,}){0,2})\s+(?:हूँ|हूं|है)'),
      RegExp(r'माझे नाव\s+([^\s,।.]{2,}(?:\s+[^\s,।.]{2,}){0,3})'),
      RegExp(r'मी\s+([^\s,।.]{2,}(?:\s+[^\s,।.]{2,}){0,2})\s+(?:आहे|आहो)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        return m.group(1)!.trim();
      }
    }
    return '';
  }

  static String _extractDate(String text) {
    final patterns = <RegExp>[
      RegExp(
          r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b'),
      RegExp(
          r'\b(\d{1,2}\s+(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4})\b',
          caseSensitive: false),
      RegExp(r'\b(yesterday|today|last night|this morning)\b',
          caseSensitive: false),
      RegExp(r'(आज|कल|काल|परसों|गत रात|आज सुबह)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) return m.group(1)!.trim();
    }
    return '';
  }

  static String _extractTime(String text) {
    final patterns = <RegExp>[
      RegExp(
          r'\b((?:at\s+)?\d{1,2}(?::\d{2})?\s*(?:am|pm|a\.m\.|p\.m\.)?)\b',
          caseSensitive: false),
      RegExp(r'(सुबह|शाम|रात|दोपहर|सकाळी|संध्याकाळी|रात्री|दुपारी)\s*(?:\d{1,2}(?:[:.]\d{2})?)?'),
      RegExp(r'(?:at around|around|about)\s+(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)',
          caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) return m.group(0)!.trim();
    }
    return '';
  }

  static String _extractLocation(String text) {
    final patterns = <RegExp>[
      RegExp(
        r'(?:at|in|near|outside|inside)\s+([A-Z][A-Za-z0-9 ,.-]{2,60}?)(?=[.,;]|$)',
      ),
      RegExp(
        r'(?:स्थान|जगह|पते|पता|में|पर)\s*[:\-]?\s*([^\n।.]{3,60})',
      ),
      RegExp(
        r'(?:येथे|इथे|जवळ|गावात|पत्त्यावर)\s*[:\-]?\s*([^\n।.]{3,60})',
      ),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) return m.group(1)!.trim();
    }
    return '';
  }

  static String _extractOffence(String text) {
    final lower = text.toLowerCase();
    const map = <String, List<String>>{
      'Theft / चोरी': [
        'theft',
        'stolen',
        'steal',
        'chori',
        'चोरी',
        'चोरीला',
        'चोरले',
        'चोरी झाली',
      ],
      'Robbery / डकैती': ['robbery', 'looted', 'snatched', 'डकैती', 'लूट', 'लुटले'],
      'Assault / मारपीट': [
        'assault',
        'beaten',
        'hit me',
        'attacked',
        'मारपीट',
        'मारहाई',
        'मारले',
        'पीटा',
      ],
      'Cheating / ठगी': [
        'cheating',
        'fraud',
        'scam',
        'duped',
        'ठगी',
        'फसवणूक',
        'धोखा',
      ],
      'Harassment / छेड़छाड़': [
        'harassment',
        'eve teasing',
        'stalking',
        'छेड़छाड़',
        'छेडछाड',
        'छळ',
      ],
      'Accident / अपघात': ['accident', 'collision', 'अपघात', 'दुर्घटना'],
      'Missing person / गुमशुदगी': ['missing', 'गुम', 'लापता'],
      'Criminal intimidation / धमकी': ['threat', 'threatened', 'धमकी', 'धमकवले'],
    };

    for (final entry in map.entries) {
      for (final k in entry.value) {
        if (lower.contains(k.toLowerCase()) || text.contains(k)) {
          return entry.key;
        }
      }
    }
    return 'Cognisable offence as narrated (to be classified by duty officer)';
  }

  static String _extractAccused(String text) {
    final patterns = <RegExp>[
      RegExp(
        r'(?:accused|suspect|by a (?:man|woman|person) named|named)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,3})',
        caseSensitive: false,
      ),
      RegExp(r'(?:आरोपी|संदिग्ध|नाम है)\s*[:\-]?\s*([^\n।.]{2,40})'),
      RegExp(r'(?:आरोपी|संशयित)\s*[:\-]?\s*([^\n।.]{2,40})'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) return m.group(1)!.trim();
    }
    if (RegExp(r'\bunknown\b|अज्ञात|माहित नाही', caseSensitive: false)
        .hasMatch(text)) {
      return 'Unknown / not identified by complainant';
    }
    return '';
  }

  static String _summarise(String transcript) {
    final words = transcript.trim().split(RegExp(r'\s+'));
    if (words.length <= 28) return transcript;
    return '${words.take(28).join(' ')}…';
  }

  static List<ReportSection> toSections(
    ParsedFirFields fields, {
    required PoliceReport draft,
  }) {
    final now = DateTime.now();
    final low = draft.isLowConfidence;
    String orDash(String v, String fallback) =>
        v.trim().isEmpty ? fallback : v.trim();

    return [
      ReportSection(
        title: 'Police Station & District',
        content: [
          if (draft.station.isNotEmpty) 'Police Station: ${draft.station}',
          if (draft.district.isNotEmpty) 'District: ${draft.district}',
          if (draft.station.isEmpty && draft.district.isEmpty)
            'To be filled at the police station.',
        ].join('\n'),
        timestamp: now,
      ),
      ReportSection(
        title: 'Complainant / Informant',
        content: [
          'Name: ${orDash(fields.complainantName.isNotEmpty ? fields.complainantName : draft.complainantName, 'As per narration / to be confirmed')}',
          if (draft.complainantPhone.isNotEmpty)
            'Phone: ${draft.complainantPhone}',
          if (draft.complainantAddress.isNotEmpty)
            'Address: ${draft.complainantAddress}',
        ].join('\n'),
        timestamp: now,
        lowConfidence: low && fields.complainantName.isEmpty,
      ),
      ReportSection(
        title: 'Date & Time of Occurrence',
        content: [
          'Date: ${orDash(fields.occurrenceDate, 'Not clearly stated — please confirm')}',
          'Time: ${orDash(fields.occurrenceTime, 'Not clearly stated — please confirm')}',
        ].join('\n'),
        timestamp: now,
        lowConfidence: low ||
            (fields.occurrenceDate.isEmpty && fields.occurrenceTime.isEmpty),
      ),
      ReportSection(
        title: 'Place of Occurrence',
        content: orDash(
          fields.placeOfOccurrence,
          'Location not clearly extracted — please edit.',
        ),
        timestamp: now,
        lowConfidence: fields.placeOfOccurrence.isEmpty,
      ),
      ReportSection(
        title: 'Nature of Offence',
        content: orDash(
          fields.natureOfOffence,
          'To be classified by the duty officer.',
        ),
        timestamp: now,
      ),
      ReportSection(
        title: 'Particulars of Accused (if known)',
        content: orDash(
          fields.accusedDetails,
          'Not mentioned in the narration.',
        ),
        timestamp: now,
      ),
      ReportSection(
        title: 'Brief Facts of the Case',
        content: orDash(
          fields.incidentDescription,
          'No narration recorded.',
        ),
        timestamp: now,
        lowConfidence: low,
      ),
      ReportSection(
        title: 'Note',
        content:
            'This is an AI-assisted FIR draft for review. It is not a legally filed FIR and is not submitted to CCTNS.',
        timestamp: now,
      ),
    ];
  }
}
