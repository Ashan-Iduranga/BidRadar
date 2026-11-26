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

void main() {
  testWidgets('a missing field is shown inline and nothing typed is lost', (
    tester,
  ) async {
    // Tall enough that the whole form is on screen.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          textOcrProvider.overrideWithValue(FakeOcr()),
          noticeReaderProvider.overrideWithValue(DownReader()),
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
}
