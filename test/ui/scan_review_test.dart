import 'dart:io';
import 'dart:typed_data';

import 'package:bidradar/core/theme/app_theme.dart';
import 'package:bidradar/domain/scan/scan.dart';
import 'package:bidradar/ui/scan/scan_page.dart';
import 'package:bidradar/ui/scan/scan_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const ocr =
    'INVITATION FOR BIDS. Ministry of Health. Bidders must hold ISO 9001 '
    'certification. Bids must be submitted no later than 30 June 2027.';

class FakeOcr implements TextOcr {
  @override
  Future<String> read(String imagePath) async => ocr;
}

/// The AI is down, so every field starts empty.
class DownReader implements NoticeReader {
  @override
  Future<ScannedNotice> read({
    required Uint8List image,
    required String mimeType,
    required String ocrText,
  }) => Future.error(Exception('quota'));
}

/// The AI misreads the year of the deadline.
class OldYearReader implements NoticeReader {
  @override
  Future<ScannedNotice> read({
    required Uint8List image,
    required String mimeType,
    required String ocrText,
  }) async => ScannedNotice(
    title: 'Hospital system',
    buyer: 'Ministry of Health',
    deadline: DateTime(1996, 6, 30, 14),
    country: 'LKA',
    requirements: const [],
  );
}

Future<void> openReview(WidgetTester tester, NoticeReader reader) async {
  // Tall enough that the whole form is on screen.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        textOcrProvider.overrideWithValue(FakeOcr()),
        noticeReaderProvider.overrideWithValue(reader),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const ScanPage()),
    ),
  );
  await tester.pump();
  final photo = File('${Directory.systemTemp.path}/br_scan_review.jpg');
  await tester.runAsync(() async {
    await photo.writeAsBytes([1, 2, 3]);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ScanPage)),
    );
    await container.read(scanViewModelProvider.notifier).process(photo.path);
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the bottom buttons stay above the navigation bar', (
    tester,
  ) async {
    // Edge to edge with 3-button navigation: 48 dp at the bottom.
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light(), home: const ScanPage()),
      ),
    );
    await tester.pumpAndSettle();
    // No camera in tests, so the page shows its start state.
    final sample = find.text('Try a sample notice (debug)');
    expect(tester.getRect(sample).bottom, lessThanOrEqualTo(780 - 48));
  });

  testWidgets('a misread deadline year still opens the date picker', (
    tester,
  ) async {
    await openReview(tester, OldYearReader());
    await tester.tap(find.text('Deadline'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('the currency field keeps its own text across rebuilds', (
    tester,
  ) async {
    await openReview(tester, DownReader());
    final currency = find.widgetWithText(TextField, 'Currency');
    await tester.enterText(currency, 'lk');
    // Any other change rebuilds the form.
    await tester.tap(find.text('Show scanned text'));
    await tester.pump();
    final field = tester.widget<TextField>(currency);
    expect(field.controller!.text, 'lk');
    expect(field.controller!.selection.baseOffset, 2);
  });

  testWidgets('a missing field is shown inline and nothing typed is lost', (
    tester,
  ) async {
    await openReview(tester, DownReader());
    expect(find.textContaining('The AI could not read this notice'), findsOne);

    await tester.enterText(
      find.widgetWithText(TextField, 'Buyer'),
      'Ministry of Health',
    );
    await tester.tap(find.text('Save and judge'));
    await tester.pumpAndSettle();

    // Still the review form, with the problems next to their fields.
    expect(find.text('Fix the fields marked above.'), findsOneWidget);
    expect(find.text('Add a title.'), findsOneWidget);
    expect(find.text('Confirm the deadline.'), findsOneWidget);
    expect(find.text('Ministry of Health'), findsOneWidget);
    expect(find.text('Could not scan'), findsNothing);

    // Typing a title clears its problem.
    await tester.enterText(
      find.widgetWithText(TextField, 'What is being bought'),
      'Hospital system',
    );
    await tester.pump();
    expect(find.text('Add a title.'), findsNothing);
  });

  group('deadline picker range', () {
    final now = DateTime(2026, 11, 30, 10);

    test('a misread year far in the past opens at the first date', () {
      final r = deadlinePickerRange(DateTime(1996, 6, 30, 14), now);
      expect(r.initial, r.first);
      expect(r.first, DateTime(2016));
    });

    test('a year far ahead opens at the last date', () {
      final r = deadlinePickerRange(DateTime(2099), now);
      expect(r.initial, r.last);
    });

    test('a normal deadline, or none, is kept', () {
      expect(
        deadlinePickerRange(DateTime(2027, 6, 30, 14), now).initial,
        DateTime(2027, 6, 30, 14),
      );
      expect(
        deadlinePickerRange(null, now).initial,
        now.add(const Duration(days: 14)),
      );
    });

    test('an old notice from last decade still opens the picker', () {
      final r = deadlinePickerRange(DateTime(2019, 3, 1), now);
      expect(r.initial, DateTime(2019, 3, 1));
    });
  });
}
