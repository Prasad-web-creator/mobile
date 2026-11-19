import 'package:flutter_test/flutter_test.dart';
import 'package:claimsupport/core/utils/text_points.dart';

void main() {
  test('status reason splits into sentences, keeping section numbers and quotes intact', () {
    const reason = "Acute Appendicitis with Appendicolith qualifies as an illness under Section B.16 "
        "('A sickness or a disease or pathological condition leading to the impairment of normal "
        "physiological function and requiring medical treatment'). It is covered under In-patient "
        "Hospitalisation (Section C.1) as the patient underwent inpatient hospitalisation for surgical "
        "treatment. Waiting periods under Section D.2 and D.3 are fully satisfied as the policy has been "
        "in continuous force since 01-Apr-2024 (924 days).";
    final points = splitIntoPoints(reason);
    expect(points, hasLength(3));
    expect(points[0], endsWith("requiring medical treatment')."));
    expect(points[1], startsWith('It is covered under In-patient Hospitalisation (Section C.1)'));
    expect(points[2], startsWith('Waiting periods under Section D.2 and D.3'));
    expect(points[2], endsWith('(924 days).'));
  });

  test('policy evidence splits per quoted clause, not inside the quote', () {
    const evidence = "Section B.16 Illness: 'A sickness or a disease. Requiring medical treatment.' "
        "Section C.1 In-patient Hospitalisation: 'The Company shall indemnify the Medical Expenses "
        "incurred for Hospitalisation of the Insured Person during the Policy Period, up to the Sum Insured...'";
    final points = splitIntoPoints(evidence);
    expect(points, hasLength(2));
    expect(points[0], "Section B.16 Illness: 'A sickness or a disease. Requiring medical treatment.'");
    expect(points[1], startsWith('Section C.1 In-patient Hospitalisation'));
  });

  test('abbreviations, decimals and apostrophes do not cause splits', () {
    final points = splitIntoPoints(
        "The policy's limit is Rs. 5,000 per day, e.g. for room rent. Refractive error under 7.5 dioptres is excluded.");
    expect(points, [
      "The policy's limit is Rs. 5,000 per day, e.g. for room rent.",
      'Refractive error under 7.5 dioptres is excluded.',
    ]);
  });

  test('existing lines and bullet markers are respected', () {
    expect(splitIntoPoints('- First point\n• Second point\n\n1. Third point'),
        ['First point', 'Second point', 'Third point']);
    expect(splitIntoPoints('Covered under In-patient Hospitalisation benefits.'),
        ['Covered under In-patient Hospitalisation benefits.']);
  });
}
