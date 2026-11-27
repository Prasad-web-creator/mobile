import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_choices.dart';
import 'package:claimsupport/core/design/widgets/app_document_row.dart';
import 'package:claimsupport/core/design/widgets/app_sheet_content.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:claimsupport/core/design/widgets/document_card.dart';
import 'package:claimsupport/core/theme/app_palette.dart';
import 'package:claimsupport/debug/component_gallery.dart';
import 'package:claimsupport/features/documents/presentation/document_summary.dart';
import 'package:claimsupport/features/home/data/check_summary.dart';
import 'package:claimsupport/features/home/presentation/widgets/check_card.dart';
import 'package:claimsupport/features/home/presentation/widgets/check_stack.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';
import 'package:claimsupport/features/prescriptions/data/models/prescription.dart';

Widget _app(Widget home, {bool reduceMotion = false}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
    extensions: const [AppPalette.light],
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(1.3), disableAnimations: reduceMotion),
    child: child!,
  ),
  home: home,
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

CheckSummary _check(String id, {String meta = ''}) => CheckSummary(
  id: id,
  treatment: 'Treatment $id',
  dateLabel: 'Today',
  meta: meta,
  statusLabel: 'Fully covered',
  statusKind: CheckStatusKind.covered,
  route: '/summary/$id',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final (family, files) in <(String, List<String>)>[
      ('Geist', ['Geist-Regular', 'Geist-Medium', 'Geist-SemiBold', 'Geist-Bold']),
      ('PhosphorRegular', ['phosphor/Phosphor']),
    ]) {
      final font = FontLoader(family);
      for (final name in files) {
        font.addFont(rootBundle.load('assets/fonts/$name.ttf'));
      }
      await font.load();
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('gallery walks all specimens at 1.3× in ${brightness.name}', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const ComponentGallery()));
      if (brightness == Brightness.dark) {
        await tester.tap(find.bySemanticsLabel('Dark'));
        await tester.pump();
      }
      await tester.runAsync(
        () => precacheImage(
          AssetImage('assets/backgrounds/home_bg_${brightness.name}.png'),
          tester.element(find.byType(ListView)),
        ),
      );
      await tester.pump(DsMotion.slow);

      final list = find.descendant(
        of: find.byType(ListView),
        matching: find.byWidgetPredicate(
          (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
        ),
      );
      Future<void> see(String label, {Finder? target}) async {
        await tester.scrollUntilVisible(
          target ?? find.text(label),
          DsSpace.s64,
          scrollable: list,
          maxScrolls: 140,
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: label);
      }

      for (final section in [
        'Check cards',
        'Check stacks',
        'Check rows',
        'Document cards',
        'Document rows',
        'Status dots and pills',
        'Section headers',
        'Filter chips',
        'Policy switchers',
        'Empty state',
        'Skeletons',
        'Inline banners',
        'Step indicators',
        'Sheet content',
      ]) {
        await see(section);
        if (section == 'Document cards') {
          await see('99+', target: find.bySemanticsLabel('Prescriptions, 99+'));
        }
        if (section == 'Filter chips') {
          await see('All');
          final filter = find.byType(AppFilterChips);
          await tester.tap(
            find.descendant(of: filter, matching: find.bySemanticsLabel('Partially covered')).hitTestable(),
          );
          await tester.pump();
          expect(tester.widget<AppFilterChips>(filter).selected, AppCheckFilter.partial);
        }
      }
      for (final (label, contents) in [
        ('Open list sheet', AppSheetList),
        ('Open key/value sheet', AppSheetKeyValue),
        ('Open confirmation sheet', AppSheetConfirmation),
      ]) {
        await see(label);
        await tester.tap(find.bySemanticsLabel(label));
        await tester.pumpAndSettle();
        expect(find.descendant(of: find.byType(AppSheet), matching: find.byType(contents)), findsWidgets);
        final modal = tester.element(find.byType(AppSheet));
        final expected = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
        expect(Theme.of(modal).bottomSheetTheme.modalBackgroundColor, expected.surfaceCardRaised);
        Navigator.of(modal).pop();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final reduceMotion in [false, true]) {
    testWidgets('stack cycles both directions and exposes working actions (reduce: $reduceMotion)', (
      tester,
    ) async {
      _phone(tester);
      final clicks = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') clicks.add(call);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final opens = <String>[];
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: AppCheckStack(
                checks: [
                  _check('A'),
                  _check('B', meta: 'For a patient whose name is long enough to wrap onto a second line'),
                  _check('C'),
                  _check('D'),
                ],
                onOpen: (value) => opens.add(value.id),
              ),
            ),
          ),
          reduceMotion: reduceMotion,
        ),
      );
      final stack = find.byType(AppCheckStack);
      final front = find.byWidgetPredicate((widget) => widget is AppCheckCard && widget.onTap != null);
      String frontId() => tester.widget<AppCheckCard>(front).check.id;
      final initialHeight = tester.getSize(stack).height;
      final initialCardHeight = tester.getSize(front).height;
      Future<void> swipe(double dx) async {
        await tester.timedDrag(front, Offset(dx, 0), const Duration(milliseconds: 600));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.getSize(stack).height, initialHeight);
        if (reduceMotion) {
          expect(
            find.descendant(of: find.byType(AppCheckStack), matching: find.byType(FractionalTranslation)),
            findsNothing,
          );
        }
        await tester.pumpAndSettle();
        expect(tester.getSize(stack).height, initialHeight);
        expect(tester.getSize(front).height, initialCardHeight);
      }

      await swipe(-60);
      expect(frontId(), 'A');
      await swipe(-145);
      expect(frontId(), 'B');
      await swipe(145);
      expect(frontId(), 'C');
      await tester.fling(front, const Offset(-60, 0), 1200);
      await tester.pumpAndSettle();
      expect(frontId(), 'D');
      await swipe(145);
      expect(frontId(), 'A');
      final item = find.bySemanticsLabel(RegExp('Treatment A'));
      final semantics = tester.getSemantics(item);
      final ids = semantics.getSemanticsData().customSemanticsActionIds!;
      final labels = ids.map((id) => CustomSemanticsAction.getAction(id)!.label).toSet();
      expect(labels, {'Next check', 'Previous check'});
      final previous = ids.singleWhere(
        (id) => CustomSemanticsAction.getAction(id)!.label == 'Previous check',
      );
      semantics.owner!.performAction(semantics.id, SemanticsAction.customAction, previous);
      await tester.pumpAndSettle();
      expect(frontId(), 'D');
      await tester.tap(front);
      expect(opens, ['D']);
      expect(clicks, hasLength(5));
    });
  }

  testWidgets('13-character document title clears the trailing caret at 1.3×', (tester) async {
    _phone(tester);
    var opens = 0;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(DsSpace.screenPadding),
            child: Row(
              spacing: DsSpace.gridGap,
              children: [
                Expanded(
                  child: AppDocumentCard(
                    type: DocumentCardType.prescription,
                    count: 100,
                    onTap: () => opens++,
                  ),
                ),
                Expanded(
                  child: AppDocumentCard(type: DocumentCardType.policy, count: 0, onTap: () {}),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final label = find.text('Prescriptions');
    final caret = find.descendant(of: find.byType(AppDocumentCard).first, matching: find.byType(Icon));
    expect(tester.getRect(label).overlaps(tester.getRect(caret)), isFalse);
    expect(tester.widget<Text>(label).overflow, isNot(TextOverflow.ellipsis));
    await tester.tap(find.bySemanticsLabel('Prescriptions, 99+'));
    expect(opens, 1);
  });

  testWidgets('shell children use Policy Pal tokens even when the parent theme is legacy', (tester) async {
    await tester.pumpWidget(
      _app(
        RootShell(
          navigation: const SizedBox.shrink(),
          body: Builder(
            builder: (context) {
              expect(Theme.of(context).colorScheme.primary, AppColors.light.buttonPrimary);
              expect(Theme.of(context).cardTheme.color, AppColors.light.surfaceCard);
              expect(context.palette.surfaceMuted, AppColors.light.surfaceCardSubtle);
              expect(context.palette.primary, AppColors.light.buttonPrimary);
              expect(DefaultTextStyle.of(context).style.fontFamily, 'Geist');
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('document rows handle nullable fields, expiration and unfamiliar server states', () {
    final now = DateTime(2026, 11, 26);
    final prescription = DocumentSummary.prescription(
      Prescription.fromJson({'diagnosis': null, 'patientName': 'N/A', 'processingStatus': 'pending'}),
      now: now,
    );
    expect(prescription.title, 'Prescription');
    expect(prescription.meta, isEmpty);
    expect(prescription.state, AppDocumentState.reading);
    expect(
      DocumentSummary.policy(
        Policy.fromJson({'processingStatus': 'future-state', 'insuranceCompany': 'Example'}),
        now: now,
      ).state,
      AppDocumentState.unknown,
    );
    expect(
      DocumentSummary.policy(
        Policy.fromJson({'policyEndDate': '2026-11-25', 'processingStatus': 'completed'}),
        now: now,
      ).state,
      AppDocumentState.expired,
    );
    expect(
      DocumentSummary.policy(Policy.fromJson({'policyEndDate': '2026-11-26'}), now: now).state,
      AppDocumentState.ready,
    );
  });
}
