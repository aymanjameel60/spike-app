import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spike_flutter_app/app/providers.dart';
import 'package:spike_flutter_app/core/network/api_client.dart';
import 'package:spike_flutter_app/core/theme.dart';
import 'package:spike_flutter_app/core/widgets/async_state_widgets.dart';
import 'package:spike_flutter_app/features/checkout/data/commerce_repository.dart';
import 'package:spike_flutter_app/features/checkout/presentation/addresses_screen.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('GraphikArabic');
    for (final f in ['Regular', 'Medium', 'Semibold', 'Bold']) {
      final bytes = File('assets/fonts/GraphikArabic-$f.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  });

  testWidgets('addresses list screen golden', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final addresses = [
      const AddressModel(
        id: 'a1', cityId: 'c1', cityName: 'صنعاء', label: 'المنزل',
        recipientName: 'أحمد محمد', phone: '777123456',
        addressLine: 'شارع حدة، جوار مركز الأمل التجاري، عمارة رقم 12، الدور الثالث',
        googleMapsUrl: 'https://maps.app.goo.gl/x', isActive: true,
      ),
      const AddressModel(
        id: 'a2', cityId: 'c1', cityName: 'صنعاء', label: 'مكتب',
        recipientName: 'أحمد محمد', phone: '777123456',
        addressLine: 'شعوب، طريق ستين الغربي، مجمع النور، مكتب 4',
        googleMapsUrl: 'https://maps.app.goo.gl/y', isActive: false,
      ),
      const AddressModel(
        id: 'a3', cityId: 'c2', cityName: 'عدن', label: 'أخرى',
        recipientName: 'سارة علي', phone: '733998877',
        addressLine: 'المنصورة، شارع المطار، منزل الجدة',
        googleMapsUrl: 'https://maps.app.goo.gl/z', isActive: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hasSessionProvider.overrideWith((ref) async => true),
          addressesProvider.overrideWith((ref) async => addresses),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          debugShowCheckedModeBanner: false,
          theme: spikeTheme,
          home: const AddressesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(find.byType(AddressesScreen), matchesGoldenFile('goldens/addresses_list.png'));
  });

  testWidgets('address form screen golden', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          citiesProvider.overrideWith((ref) async => const [
            CityModel(id: 'c1', name: 'صنعاء'),
            CityModel(id: 'c2', name: 'عدن'),
            CityModel(id: 'c3', name: 'تعز'),
          ]),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          debugShowCheckedModeBanner: false,
          theme: spikeTheme,
          home: const AddressFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(find.byType(AddressFormScreen), matchesGoldenFile('goldens/addresses_form.png'));
  });

  testWidgets('addresses guest shows login required', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hasSessionProvider.overrideWith((ref) async => false),
          addressesProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          debugShowCheckedModeBanner: false,
          theme: spikeTheme,
          home: const AddressesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('سجّل الدخول لإدارة عناوينك'), findsOneWidget);
    expect(find.byType(SpikeErrorState), findsNothing);
    await expectLater(find.byType(AddressesScreen), matchesGoldenFile('goldens/addresses_guest.png'));
  });

  testWidgets('addresses expired session (401) shows login view instead of raw error', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hasSessionProvider.overrideWith((ref) async => true),
          addressesProvider.overrideWith((ref) async => throw const ApiException('unauthorized', statusCode: 401)),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          debugShowCheckedModeBanner: false,
          theme: spikeTheme,
          home: const AddressesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('انتهت صلاحية الجلسة'), findsOneWidget);
    expect(find.byType(SpikeErrorState), findsNothing);
  });
}
