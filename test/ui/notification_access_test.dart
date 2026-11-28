import 'package:bidradar/core/notifications/notification_service.dart';
import 'package:bidradar/core/theme/app_theme.dart';
import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/data/providers.dart';
import 'package:bidradar/domain/reminders/reminder_planner.dart';
import 'package:bidradar/ui/account/account_page.dart';
import 'package:bidradar/ui/deadlines/deadlines_view_model.dart';
import 'package:bidradar/ui/pipeline/pipeline_view_model.dart';
import 'package:bidradar/ui/settings/notification_access.dart';
import 'package:bidradar/ui/settings/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android's notification permission, played by the test.
class FakeNotifications extends NotificationService {
  FakeNotifications({this.allowed = true});

  bool allowed;
  int asked = 0;
  int opened = 0;
  final scheduled = <List<PlannedReminder>>[];

  @override
  Future<bool?> requestPermission() async {
    asked++;
    return allowed;
  }

  @override
  Future<bool?> areEnabled() async => allowed;

  @override
  Future<bool> openSettings() async {
    opened++;
    return true;
  }

  @override
  Future<int> scheduleReminders(List<PlannedReminder> planned) async {
    scheduled.add(planned);
    return planned.length;
  }
}

Bid watching(DateTime deadline) => Bid(
  id: 'b1',
  tenderId: 't1',
  companyId: 'c',
  stage: BidStage.watching,
  ownerUid: 'u',
  updatedAt: DateTime.now(),
  title: 'Patient records system',
  buyer: 'Ministry of Health',
  deadline: deadline,
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer container(FakeNotifications fake) {
    final c = ProviderContainer(
      overrides: [
        notifierProvider.overrideWithValue(fake),
        sharedPrefsProvider.overrideWithValue(prefs),
        bidsProvider.overrideWith(
          (ref) => Stream.value([
            watching(DateTime.now().add(const Duration(days: 10))),
          ]),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('asks once, on the first launch that reads it', () async {
    final fake = FakeNotifications();
    final first = container(fake);
    expect(
      await first.read(notificationAccessProvider.future),
      NotificationAccess.allowed,
    );
    expect(fake.asked, 1);
    expect(prefs.getBool(notificationsAskedKey), isTrue);

    // A later launch only reads Android's answer.
    final again = container(fake..allowed = false);
    expect(
      await again.read(notificationAccessProvider.future),
      NotificationAccess.blocked,
    );
    expect(fake.asked, 1);
  });

  test('reminders wait for the answer, then follow it', () async {
    final fake = FakeNotifications();
    final c = container(fake);
    final sub = c.listen(reminderSyncProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(notificationAccessProvider.future);
    await c.read(bidsProvider.future);
    await pumpEventQueue();
    expect(fake.scheduled.last, isNotEmpty);

    // Blocked in Android settings while the app was away.
    fake.allowed = false;
    await c.read(notificationAccessProvider.notifier).refresh();
    await pumpEventQueue();
    expect(fake.scheduled.last, isEmpty);
  });

  testWidgets('Profile switches show off and explain when blocked', (
    tester,
  ) async {
    final fake = FakeNotifications(allowed: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notifierProvider.overrideWithValue(fake),
          sharedPrefsProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const AccountPage()),
      ),
    );
    await tester.pumpAndSettle();

    final reminders = find.widgetWithText(SwitchListTile, 'Deadline reminders');
    await tester.scrollUntilVisible(reminders, 200);
    await tester.ensureVisible(reminders);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(reminders).value, isFalse);
    expect(find.textContaining('Notifications are off'), findsOneWidget);

    // Turning it on asks again; still denied, so it offers settings.
    await tester.tap(reminders);
    await tester.pumpAndSettle();
    expect(fake.asked, 2);
    expect(
      find.text('Allow notifications for BidRadar in Android settings.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(SnackBarAction, 'Open settings'));
    await tester.pumpAndSettle();
    expect(fake.opened, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
