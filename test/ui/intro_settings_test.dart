import 'package:bidradar/core/theme/app_theme.dart';
import 'package:bidradar/ui/intro/intro_page.dart';
import 'package:bidradar/ui/settings/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('intro', () {
    Future<ProviderContainer> pumpIntro(
      WidgetTester tester, {
      bool reduceMotion = false,
    }) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduceMotion),
              child: const IntroPage(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      return container;
    }

    testWidgets('three steps, then Get started marks the intro as seen', (
      tester,
    ) async {
      final container = await pumpIntro(tester);
      expect(find.text('Find tenders you can win'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);

      for (final title in ['Know before you bid', 'Never miss a deadline']) {
        await tester.tap(find.bySemanticsLabel('Next'));
        // Page slide, then the rebuild for the new page.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text(title), findsOneWidget);
      }
      expect(find.bySemanticsLabel('Step 3 of 3'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);

      expect(container.read(settingsProvider).introSeen, isFalse);
      await tester.tap(find.bySemanticsLabel('Get started'));
      // The colour reveal runs, then the flag is saved.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(container.read(settingsProvider).introSeen, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Skip works at once when animations are off', (tester) async {
      final container = await pumpIntro(tester, reduceMotion: true);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(container.read(settingsProvider).introSeen, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('settings', () {
    test('defaults: system theme, intro unseen, both alerts on', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final s = c.read(settingsProvider);
      expect(s.themeMode, ThemeMode.system);
      expect(s.introSeen, isFalse);
      expect(s.deadlineReminders, isTrue);
      expect(s.newTenderAlerts, isTrue);
    });

    test('changes are saved on the device and read back', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      final vm = c.read(settingsProvider.notifier);
      await vm.setThemeMode(ThemeMode.dark);
      await vm.setDeadlineReminders(false);
      await vm.setNewTenderAlerts(false);
      await vm.markIntroSeen();

      final again = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(again.dispose);
      expect(
        again.read(settingsProvider),
        const AppSettings(
          themeMode: ThemeMode.dark,
          introSeen: true,
          deadlineReminders: false,
          newTenderAlerts: false,
        ),
      );
      // The background isolate reads the same key.
      expect(await newTenderAlertsEnabled(), isFalse);
    });
  });
}
