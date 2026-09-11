import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/api_config.dart';
import 'core/settings/app_settings.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SpikeApp()));
  unawaited(_bootstrapMediaContract());
}

Future<void> _bootstrapMediaContract() async {
  try {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        responseType: ResponseType.json,
        headers: const {'accept': 'application/json'},
      ),
    );
    final response = await dio.get<Object?>(ApiConfig.mediaConfigUrl);
    final data = response.data;
    if (data is! Map) {
      debugPrint('[Spike media] Invalid /media/config response shape.');
      return;
    }
    final configured = ApiConfig.configureMediaContract(
      storageValue: data['storage_value'],
      publicBaseUrl: data['public_base_url'],
    );
    if (!configured) {
      debugPrint('[Spike media] Invalid media contract; using backend resolver fallback.');
    }
  } catch (error) {
    // Media bootstrap is intentionally outside the app startup critical path.
    // `/media/file/<object-key>` remains the backend-owned fallback.
    debugPrint('[Spike media] Media bootstrap failed; using resolver fallback: $error');
  }
}

class SpikeApp extends ConsumerWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final rtl = settings.language == 'ar';
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Spike',
      theme: spikeTheme,
      darkTheme: spikeDarkTheme,
      themeMode: settings.themeMode,
      locale: Locale(settings.language),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
      builder: (context, child) => Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
