import 'dart:convert';

import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/features/summary/presentation/screens/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _condition =
    'Covered only if your eye power (refractive error) is 7.5 dioptres or more. Below 7.5 dioptres the policy excludes it.';

Map<String, dynamic> _report({
  required List<Map<String, dynamic>> comparison,
  required Map<String, dynamic> breakdown,
  required String overall,
}) {
  return {
    'overallStatus': overall,
    'dominanceScore': 50.0,
    'coverageBreakdown': breakdown,
    'comparison': comparison,
    'policyJson': {
      'insuranceCompany': 'Suraksha Shield General Insurance Co. Ltd.',
      'policyNumber': 'SSGI/HLT/2026/0418-77291',
      'policyType': 'Family Floater',
      'coverageAmount': 1000000,
    },
    'prescriptionJson': {
      'diagnosis': 'lasik surgery',
      'isManual': true,
      'manualText': 'lasik surgery',
    },
    'documentValidity': {'policyValid': true, 'prescriptionValid': true},
    // Present so the screen does not try to fetch the report again.
    'processingTimeMs': 27700,
  };
}

final _needsVerificationReport = _report(
  overall: 'Needs Verification',
  comparison: [
    {
      'item': 'lasik surgery',
      'status': 'Needs Verification',
      'coverageStatus': 'Needs Verification',
      'isCovered': false,
      'coverageStatusReason': 'LASIK is covered only if the refractive error is 7.5 dioptres or more.',
      'verificationCondition': _condition,
      'verificationClause': 'Section 5.12 - Refractive error',
      'policyEvidence': 'Section 5.12: Refractive error less than 7.5 dioptres is excluded.',
      'financialDecision': 'The payable amount depends on the detail that needs verification.',
    },
    {'item': 'consultation', 'status': 'Covered', 'coverageStatus': 'Covered', 'isCovered': true},
  ],
  breakdown: {'covered': 1, 'partiallyCovered': 0, 'notCovered': 0, 'needsVerification': 1, 'total': 2},
);

// An old report: no Needs Verification item and no needsVerification count.
final _oldReport = _report(
  overall: 'Covered',
  comparison: [
    {'item': 'appendectomy', 'status': 'Covered', 'coverageStatus': 'Covered', 'isCovered': true},
  ],
  breakdown: {'covered': 1, 'partiallyCovered': 0, 'notCovered': 0, 'total': 1},
);

/// Renders the summary for [report] on a phone-sized screen and returns the
/// source locations of any widgets that overflowed.
Future<Set<String>> _pumpSummary(WidgetTester tester, Map<String, dynamic> report) async {
  tester.view.physicalSize = const Size(360 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPrefs.init();
  await prefs.setString('analysis_result', jsonEncode(report));

  final overflows = <String>{};
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    if (text.contains('overflowed')) {
      final source = RegExp(r'[\w_]+\.dart:\d+').firstMatch(text.split('error-causing widget').last);
      overflows.add(source?.group(0) ?? text);
    } else {
      previous?.call(details);
    }
  };

  // The test font draws every glyph as a full square, about twice as wide as
  // the app's real font; scaling text by 0.55 approximates real text widths.
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.55)),
        child: child!,
      ),
      home: SummaryScreen(key: UniqueKey()),
    ),
  ));
  await tester.pumpAndSettle();
  FlutterError.onError = previous;
  return overflows;
}

void main() {
  testWidgets('older manual review reports show the unresolved item count', (tester) async {
    await _pumpSummary(tester, _report(
      overall: 'Manual Review Required',
      comparison: [{'item': 'Example item', 'coverageStatus': 'Manual Review'}],
      breakdown: {'covered': 0, 'partiallyCovered': 0, 'notCovered': 0, 'total': 1},
    ));
    expect(find.text('1 item needs manual review before coverage can be determined.'), findsOneWidget);
    expect(find.text('No evaluated claim items available.'), findsNothing);
    expect(find.text('Dominance Score'), findsNothing);
  });

  testWidgets('Needs Verification report: card above Policy Summary, 4th count, no new overflow', (tester) async {
    final baseline = await _pumpSummary(tester, _oldReport);
    expect(find.text('Needs Verification'), findsNothing);

    final overflows = await _pumpSummary(tester, _needsVerificationReport);
    // Nothing added by the Needs Verification UI overflows at phone width.
    expect(overflows.difference(baseline), isEmpty);

    // Header, breakdown, card title, table and detail status, donut legend.
    expect(find.text('Needs Verification'), findsWidgets);
    expect(find.text(_condition), findsOneWidget);
    expect(find.textContaining('Clause: Section 5.12 - Refractive error', findRichText: true), findsOneWidget);

    // The card sits above the Policy Summary card.
    final cardTop = tester.getTopLeft(find.text(_condition)).dy;
    final policyTop = tester.getTopLeft(find.text('Policy Summary')).dy;
    expect(cardTop, lessThan(policyTop));
  });
}
