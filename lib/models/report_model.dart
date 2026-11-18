import 'package:uuid/uuid.dart';

enum ReportStatus { draft, completed, submitted }

enum Language {
  auto('Auto-detect', '', 'Auto'),
  hindi('Hindi', 'hi-IN', 'हिन्दी'),
  english('English', 'en-IN', 'English'),
  marathi('Marathi', 'mr-IN', 'मराठी');

  final String name;
  final String code;
  final String nativeName;
  const Language(this.name, this.code, this.nativeName);

  static Language fromName(String? value) {
    return Language.values.firstWhere(
      (l) => l.name == value || l.name.toLowerCase() == value?.toLowerCase(),
      orElse: () => Language.english,
    );
  }
}

class ReportSection {
  final String title;
  String content;
  final DateTime timestamp;
  final bool lowConfidence;

  ReportSection({
    required this.title,
    required this.content,
    required this.timestamp,
    this.lowConfidence = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'lowConfidence': lowConfidence,
      };

  factory ReportSection.fromJson(Map<String, dynamic> json) {
    return ReportSection(
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      lowConfidence: json['lowConfidence'] as bool? ?? false,
    );
  }
}

/// Structured FIR draft aligned with BR-04 / BR-05 (public FIR field set).
class PoliceReport {
  final String id;
  final String reportNumber;
  ReportStatus status;
  Language language;
  String complainantName;
  String complainantPhone;
  String complainantAddress;
  String officerId;
  String officerName;
  String badgeNumber;
  String station;
  String district;
  String occurrenceDate;
  String occurrenceTime;
  String placeOfOccurrence;
  String natureOfOffence;
  String accusedDetails;
  DateTime createdAt;
  DateTime updatedAt;
  List<ReportSection> sections;
  String rawTranscript;
  String summary;
  double confidenceScore;

  PoliceReport({
    String? id,
    String? reportNumber,
    this.status = ReportStatus.draft,
    this.language = Language.english,
    this.complainantName = '',
    this.complainantPhone = '',
    this.complainantAddress = '',
    this.officerId = '',
    this.officerName = '',
    this.badgeNumber = '',
    this.station = '',
    this.district = '',
    this.occurrenceDate = '',
    this.occurrenceTime = '',
    this.placeOfOccurrence = '',
    this.natureOfOffence = '',
    this.accusedDetails = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ReportSection>? sections,
    this.rawTranscript = '',
    this.summary = '',
    this.confidenceScore = 0.0,
  })  : id = id ?? const Uuid().v4(),
        reportNumber = reportNumber ?? _generateReportNumber(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        sections = sections ?? [];

  bool get isLowConfidence =>
      confidenceScore > 0 && confidenceScore < 0.7;

  static String _generateReportNumber() {
    final now = DateTime.now();
    return 'NV-FIR-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${(1000 + now.millisecond).toString()}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reportNumber': reportNumber,
        'status': status.name,
        'language': language.name,
        'complainantName': complainantName,
        'complainantPhone': complainantPhone,
        'complainantAddress': complainantAddress,
        'officerId': officerId,
        'officerName': officerName,
        'badgeNumber': badgeNumber,
        'station': station,
        'district': district,
        'occurrenceDate': occurrenceDate,
        'occurrenceTime': occurrenceTime,
        'placeOfOccurrence': placeOfOccurrence,
        'natureOfOffence': natureOfOffence,
        'accusedDetails': accusedDetails,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'sections': sections.map((s) => s.toJson()).toList(),
        'rawTranscript': rawTranscript,
        'summary': summary,
        'confidenceScore': confidenceScore,
      };

  factory PoliceReport.fromJson(Map<String, dynamic> json) {
    return PoliceReport(
      id: json['id'] as String?,
      reportNumber: json['reportNumber'] as String?,
      status: ReportStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ReportStatus.draft,
      ),
      language: Language.fromName(json['language'] as String?),
      complainantName: json['complainantName'] as String? ?? '',
      complainantPhone: json['complainantPhone'] as String? ?? '',
      complainantAddress: json['complainantAddress'] as String? ?? '',
      officerId: json['officerId'] as String? ?? '',
      officerName: json['officerName'] as String? ?? '',
      badgeNumber: json['badgeNumber'] as String? ?? '',
      station: json['station'] as String? ?? '',
      district: json['district'] as String? ?? '',
      occurrenceDate: json['occurrenceDate'] as String? ?? '',
      occurrenceTime: json['occurrenceTime'] as String? ?? '',
      placeOfOccurrence: json['placeOfOccurrence'] as String? ?? '',
      natureOfOffence: json['natureOfOffence'] as String? ?? '',
      accusedDetails: json['accusedDetails'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      sections: (json['sections'] as List<dynamic>? ?? [])
          .map((s) => ReportSection.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
      rawTranscript: json['rawTranscript'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
