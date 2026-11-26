import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'ui/settings/settings_providers.dart';

class BidRadarApp extends ConsumerWidget {
  const BidRadarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'BidRadar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(settingsProvider.select((s) => s.themeMode)),
      themeAnimationDuration: const Duration(milliseconds: 300),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
