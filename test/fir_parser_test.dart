import 'package:flutter_test/flutter_test.dart';
import 'package:nyayvaani/models/report_model.dart';
import 'package:nyayvaani/services/fir_parser.dart';

/// Mirrors server/test/parser.test.js: the app and server parsers must agree.
void main() {
  group('FirParser', () {
    test('English burglary at night', () {
      final r = FirParser.parse(
          'My name is Sunita Deshmukh. Last night around 11 pm someone broke into my house at Gandhi Nagar and stole gold jewellery.');
      expect(r.complainantName, 'Sunita Deshmukh');
      expect(r.occurrenceDate, 'Last night');
      expect(r.occurrenceTime, '11 pm');
      expect(r.placeOfOccurrence, 'Gandhi Nagar');
      expect(r.natureOfOffence, startsWith('Theft'));
    });

    test('English snatching with named accused', () {
      final r = FirParser.parse(
          'I am Rahul Sharma. Two men on a bike snatched my phone near City Mall yesterday at 8:15 pm. The accused is Vikas Patil.');
      expect(r.complainantName, 'Rahul Sharma');
      expect(r.occurrenceTime, '8:15 pm');
      expect(r.placeOfOccurrence, 'City Mall');
      expect(r.natureOfOffence, startsWith('Robbery'));
      expect(r.accusedDetails, 'Vikas Patil');
    });

    test('amounts are not times, months are not places', () {
      final a = FirParser.parse(
          'I am Mohan Das. I was cheated of 50000 rupees in an online fraud on 05/11/2026.');
      expect(a.occurrenceTime, '');
      expect(a.occurrenceDate, '05/11/2026');
      final b = FirParser.parse(
          'My phone was stolen in March at Nashik Road Station.');
      expect(b.placeOfOccurrence, 'Nashik Road Station');
    });

    test('an ordinary sentence is not a name', () {
      final r =
          FirParser.parse('I am going to the market and my bag was stolen.');
      expect(r.complainantName, '');
    });

    test('a lost phone is not a missing person', () {
      expect(FirParser.parse('My phone is missing since morning.').natureOfOffence,
          startsWith('Cognisable'));
      expect(FirParser.parse('My son is missing since yesterday evening.').natureOfOffence,
          startsWith('Missing'));
    });

    test('Hindi burglary', () {
      final r = FirParser.parse(
          'मेरा नाम सुनील पाटिल है। कल रात लगभग 11 बजे मेरे घर में चोरी हुई।');
      expect(r.complainantName, 'सुनील पाटिल');
      expect(r.occurrenceTime, '11 बजे');
      expect(r.placeOfOccurrence, 'मेरे घर');
      expect(r.natureOfOffence, startsWith('Theft'));
    });

    test('Marathi accident', () {
      final r = FirParser.parse(
          'माझे नाव अमित पाटील आहे. काल सकाळी 9 वाजता नाशिक येथे अपघात झाला.');
      expect(r.complainantName, 'अमित पाटील');
      expect(r.occurrenceTime, '9 वाजता');
      expect(r.placeOfOccurrence, 'नाशिक');
      expect(r.natureOfOffence, startsWith('Accident'));
    });

    test('language detection does not mistake Hindi words for Marathi', () {
      expect(FirParser.detectLanguage('एक आदमी ने मेरा फोन छीना'),
          Language.hindi);
      expect(FirParser.detectLanguage('माझा फोन चोरीला गेला आहे'),
          Language.marathi);
      expect(FirParser.detectLanguage('my phone was stolen'), Language.english);
    });

    test('empty text gives empty fields', () {
      final r = FirParser.parse('   ');
      expect(r.complainantName, '');
      expect(r.natureOfOffence, '');
    });
  });

  group('PoliceReport', () {
    test('review status controls locking', () {
      final r = PoliceReport();
      expect(r.isLocked, isFalse);
      r.reviewStatus = 'pending';
      expect(r.isLocked, isTrue);
      r.reviewStatus = 'returned';
      expect(r.isLocked, isFalse);
      expect(r.isReturned, isTrue);
      r.reviewStatus = 'approved';
      expect(r.isLocked, isTrue);
    });

    test('JSON round trip keeps review fields', () {
      final r = PoliceReport(reportNumber: 'NV-FIR-1')
        ..reviewStatus = 'returned'
        ..reviewComment = 'Add accused'
        ..officerRank = 'SI';
      final back = PoliceReport.fromJson(r.toJson());
      expect(back.reviewStatus, 'returned');
      expect(back.reviewComment, 'Add accused');
      expect(back.officerRank, 'SI');
    });

    test('report numbers are unique', () {
      final numbers = {for (var i = 0; i < 500; i++) PoliceReport().reportNumber};
      expect(numbers.length, 500);
    });
  });
}
