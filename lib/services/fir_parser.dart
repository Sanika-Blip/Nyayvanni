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
///
/// NOTE: mirrors server/src/parser.js so offline results match online ones.
/// Keep the two in sync when editing.
class FirParser {
  // Devanagari-aware "word boundaries" (\b does not work for Devanagari).
  static const String _nb = r'(?<![ऀ-ॿ])';
  static const String _na = r'(?![ऀ-ॿ])';

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
    final hasDevanagari = RegExp(r'[ऀ-ॿ]').hasMatch(text);
    if (!hasDevanagari) return Language.english;
    // Whole-word markers only: "मी" must not match inside Hindi words like "आदमी".
    if (RegExp('$_nb(आहे|आहेत|माझे|माझा|माझी|मी|येथे|इथे|झाली|झाले)$_na')
        .hasMatch(text)) {
      return Language.marathi;
    }
    return Language.hindi;
  }

  static String _first(String text, List<RegExp> patterns) {
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) return (m.group(1) ?? m.group(0) ?? '').trim();
    }
    return '';
  }

  static String _extractName(String text) {
    return _first(text, <RegExp>[
      // The trigger phrase may be any case, but the captured name must be capitalised.
      RegExp(
        r"(?:[Mm]y name is|[Ii] am called|[Ii]'m called|[Tt]his is|[Ii] am|[Ii]'m)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,3})",
      ),
      RegExp(
        r'(?:[Cc]omplainant|[Ii]nformant)\s+(?:is|:)\s+([A-Z][A-Za-z]*(?:\s+[A-Z][A-Za-z]*){0,3})',
      ),
      RegExp(
        r'मेरा नाम\s+([^\s,।.]{2,}(?:\s+[^\s,।.]{2,}){0,2}?)(?:\s+(?:है|हैं)|[,।.]|$)',
      ),
      RegExp(
        r'माझे नाव\s+([^\s,।.]{2,}(?:\s+[^\s,।.]{2,}){0,2}?)(?:\s+आहे|[,।.]|$)',
      ),
    ]);
  }

  static String _extractDate(String text) {
    return _first(text, <RegExp>[
      RegExp(r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b'),
      RegExp(
        r'\b(\d{1,2}\s+(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4})\b',
        caseSensitive: false,
      ),
      RegExp(r'\b(yesterday|today|last night|this morning)\b',
          caseSensitive: false),
      RegExp('$_nb(आज सुबह|गत रात|परसों|आज|कल|काल)$_na'),
    ]);
  }

  static String _extractTime(String text) {
    return _first(text, <RegExp>[
      RegExp(r'\b(\d{1,2}(?::\d{2})?\s*(?:a\.m\.|p\.m\.|am|pm))(?![a-z])',
          caseSensitive: false),
      RegExp(r'\b(?:at|around|about)\s+(\d{1,2}:\d{2})\b',
          caseSensitive: false),
      RegExp(r'\b(\d{1,2}:\d{2})\b'),
      RegExp(r"\b(\d{1,2})\s*o'?\s*clock\b", caseSensitive: false),
      RegExp(
        '(सुबह|शाम|रात|दोपहर|सकाळी|संध्याकाळी|रात्री|दुपारी)$_na'
        r'\s*(?:\d{1,2}(?:[:.]\d{2})?)?',
      ),
    ]);
  }

  static const Set<String> _timeWords = {
    'आज', 'कल', 'काल', 'परसों', 'गत', 'रात', 'सुबह', 'शाम', 'दोपहर',
    'सकाळी', 'संध्याकाळी', 'रात्री', 'दुपारी',
  };

  /// Drops leading date/time words that the postposition pattern may sweep up.
  static String _stripTimeWords(String place) {
    final words = place.split(RegExp(r'\s+'));
    while (words.length > 1 && _timeWords.contains(words.first)) {
      words.removeAt(0);
    }
    return words.join(' ');
  }

  static String _extractLocation(String text) {
    return _stripTimeWords(_first(text, <RegExp>[
      RegExp(
        r'\b(?:at|in|near|outside|inside)\s+([A-Z][A-Za-z0-9 ,.-]{2,60}?)(?=[.,;]|$)',
      ),
      RegExp(r'(?:स्थान|जगह|पते|पता)\s*[:-]?\s*([^\n।.]{3,60})'),
      // Postpositions follow the place: "<place> में / पर / के पास / येथे / जवळ".
      RegExp(
        r'([^\s।,.]+(?:\s+[^\s।,.]+){0,3})\s+(?:में|पर|के पास|येथे|इथे|जवळ)' + _na,
      ),
      RegExp(r'पत्त्यावर\s*[:-]?\s*([^\n।.]{3,60})'),
    ]));
  }

  static const Map<String, List<String>> _offences = {
    'Theft / चोरी': [
      'theft', 'stolen', 'steal', 'chori', 'चोरी', 'चोरीला', 'चोरले',
    ],
    'Robbery / डकैती': [
      'robbery', 'looted', 'snatched', 'डकैती', 'लूट', 'लुटले',
    ],
    'Assault / मारपीट': [
      'assault', 'beaten', 'hit me', 'attacked', 'मारपीट', 'मारहाण',
      'मारहाई', 'मारले', 'पीटा',
    ],
    'Cheating / ठगी': [
      'cheating', 'fraud', 'scam', 'duped', 'ठगी', 'फसवणूक', 'धोखा',
    ],
    'Harassment / छेड़छाड़': [
      'harassment', 'eve teasing', 'stalking', 'छेड़छाड़', 'छेडछाड', 'छळ',
    ],
    'Accident / अपघात': ['accident', 'collision', 'अपघात', 'दुर्घटना'],
    'Missing person / गुमशुदगी': ['लापता', 'बेपत्ता', 'गुमशुदा'],
    'Criminal intimidation / धमकी': [
      'threat', 'threatened', 'धमकी', 'धमकवले',
    ],
  };

  static bool _hasKeyword(String text, String lower, String k) {
    if (RegExp(r'^[a-z ]+$', caseSensitive: false).hasMatch(k)) {
      return RegExp('\\b${k.replaceAll(' ', r'\s+')}', caseSensitive: false)
          .hasMatch(lower);
    }
    return text.contains(k);
  }

  static String _extractOffence(String text) {
    final lower = text.toLowerCase();
    String? best;
    var bestScore = 0;
    for (final entry in _offences.entries) {
      var score = entry.value.where((k) => _hasKeyword(text, lower, k)).length;
      // "missing" means a missing person only when a person is the subject
      // ("my phone is missing" is not).
      if (entry.key.startsWith('Missing') &&
          RegExp(r'\bmissing\b', caseSensitive: false).hasMatch(text) &&
          RegExp(
            r'\b(son|daughter|child|wife|husband|brother|sister|boy|girl|person|father|mother)\b',
            caseSensitive: false,
          ).hasMatch(text)) {
        score += 1;
      }
      if (score > bestScore) {
        best = entry.key;
        bestScore = score;
      }
    }
    return best ??
        'Cognisable offence as narrated (to be classified by duty officer)';
  }

  static String _extractAccused(String text) {
    final named = _first(text, <RegExp>[
      RegExp(
        r'(?:[Aa]ccused|[Ss]uspect|by a (?:man|woman|person) named|[Nn]amed)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,3})',
      ),
      RegExp(r'(?:आरोपी|संदिग्ध|संशयित|नाम है)\s*[:-]?\s*([^\n।.]{2,40})'),
    ]);
    if (named.isNotEmpty) return named;
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
