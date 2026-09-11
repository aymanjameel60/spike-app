import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/cart/data/cart_repository.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/checkout/data/commerce_repository.dart';
import '../features/engagement/data/engagement_repository.dart';
import '../features/engagement/data/share_win_repository.dart';
import '../features/home/data/home_repository.dart';
import '../features/profile/data/marketplace_repository.dart';
import '../models/banner_item.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/store.dart';

Future<List<ProductModel>> _loadPagedProducts(
  CatalogRepository repo, {
  String? storeId,
  bool offersOnly = false,
}) async {
  const pageSize = 100;
  final first = await repo.pagedProducts(
    storeId: storeId,
    offersOnly: offersOnly,
    page: 1,
    pageSize: pageSize,
  );
  if (!first.hasNext) return first.items;

  final items = <ProductModel>[...first.items];
  final totalPages = (first.total / pageSize).ceil();

  for (var startPage = 2; startPage <= totalPages; startPage += 4) {
    final endPage = (startPage + 3).clamp(startPage, totalPages).toInt();
    final pages = await Future.wait([
      for (var page = startPage; page <= endPage; page++)
        repo.pagedProducts(
          storeId: storeId,
          offersOnly: offersOnly,
          page: page,
          pageSize: pageSize,
        ),
    ]);
    for (final result in pages) {
      items.addAll(result.items);
    }
  }
  return items;
}

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ),
);
final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(ref.watch(secureStorageProvider)),
);
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(tokenStorage: ref.watch(tokenStorageProvider)),
);
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  ),
);
final currentUserProvider = FutureProvider<Map<String, dynamic>?>(
  (ref) => ref.watch(authRepositoryProvider).me(),
);

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepository(ref.watch(apiClientProvider)),
);
final homeDataProvider = FutureProvider<HomeData>(
  (ref) => ref.watch(homeRepositoryProvider).load(),
);
final brandingLogoProvider = FutureProvider<String?>(
  (ref) => ref.watch(homeRepositoryProvider).brandingLogo(),
);
final popupBannersProvider = FutureProvider<List<BannerItem>>(
  (ref) => ref.watch(homeRepositoryProvider).popupBanners(),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(apiClientProvider)),
);
final categoriesProvider = FutureProvider<List<CategoryModel>>(
  (ref) => ref.watch(catalogRepositoryProvider).categories(),
);
final productsProvider = FutureProvider.family<List<ProductModel>, (String?, String?)>(
  (ref, query) => ref.watch(catalogRepositoryProvider).products(
        categoryId: query.$1,
        collectionId: query.$2,
      ),
);
final productProvider = FutureProvider.family<ProductModel?, String>(
  (ref, id) => ref.watch(catalogRepositoryProvider).product(id),
);
final storesProvider = FutureProvider<List<StoreModel>>(
  (ref) => ref.watch(catalogRepositoryProvider).stores(),
);
final allProductsProvider = FutureProvider<List<ProductModel>>(
  (ref) => _loadPagedProducts(ref.watch(catalogRepositoryProvider)),
);
final storeProductsProvider = FutureProvider.family<List<ProductModel>, String>(
  (ref, id) => _loadPagedProducts(
    ref.watch(catalogRepositoryProvider),
    storeId: id,
  ),
);
final offersProductsProvider = FutureProvider<List<ProductModel>>(
  (ref) => _loadPagedProducts(
    ref.watch(catalogRepositoryProvider),
    offersOnly: true,
  ),
);

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => CartRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  ),
);
final cartCountProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final cart = await ref.watch(cartRepositoryProvider).load();
    return cart.items.fold<int>(0, (sum, item) => sum + item.quantity);
  } catch (_) {
    return 0;
  }
});

final engagementRepositoryProvider = Provider<EngagementRepository>(
  (ref) => EngagementRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  ),
);
final shareWinRepositoryProvider = Provider<ShareWinRepository>(
  (ref) => ShareWinRepository(ref.watch(apiClientProvider)),
);
final shareWinPublicProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => ref.watch(shareWinRepositoryProvider).publicConfig(),
);
final shareWinMeProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(shareWinRepositoryProvider).me(),
);
final marketplaceRepositoryProvider = Provider<MarketplaceRepository>(
  (ref) => MarketplaceRepository(ref.watch(apiClientProvider)),
);
final walletProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(marketplaceRepositoryProvider).wallet(),
);
final notificationsDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    return await ref.watch(engagementRepositoryProvider).notifications();
  } catch (_) {
    return const {'notifications': <dynamic>[]};
  }
});
final unreadNotificationsProvider = Provider<int>((ref) {
  final data = ref.watch(notificationsDataProvider).valueOrNull;
  final raw = data?['notifications'];
  final items = (raw is List ? raw : const <dynamic>[]).whereType<Map>();
  return items.where((notification) => notification['read_at'] == null).length;
});
final wishlistIdsProvider = FutureProvider.autoDispose<Set<String>>(
  (ref) async => (await ref.watch(engagementRepositoryProvider).wishlistIds()).toSet(),
);
final announcementsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    return await ref.watch(engagementRepositoryProvider).announcements();
  } catch (_) {
    return const [];
  }
});
final storeReviewsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) => ref.watch(engagementRepositoryProvider).storeReviews(id),
);
final favoritesProvider = FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final ids = (await ref.watch(wishlistIdsProvider.future)).toList();
  if (ids.isEmpty) return const [];

  final repo = ref.watch(catalogRepositoryProvider);
  final items = <ProductModel>[];
  for (var start = 0; start < ids.length; start += 100) {
    final end = (start + 100 < ids.length) ? start + 100 : ids.length;
    final page = await repo.pagedProducts(
      ids: ids.sublist(start, end),
      pageSize: 100,
    );
    items.addAll(page.items);
  }
  final order = {for (var index = 0; index < ids.length; index++) ids[index]: index};
  items.sort(
    (a, b) => (order[a.id] ?? 999999).compareTo(order[b.id] ?? 999999),
  );
  return items;
});

final commerceRepositoryProvider = Provider<CommerceRepository>(
  (ref) => CommerceRepository(ref.watch(apiClientProvider)),
);
final hasSessionProvider = FutureProvider<bool>((ref) async {
  return (await ref.watch(tokenStorageProvider).readToken())?.isNotEmpty == true;
});
final citiesProvider = FutureProvider<List<CityModel>>(
  (ref) => ref.watch(commerceRepositoryProvider).cities(),
);
final addressesProvider = FutureProvider<List<AddressModel>>(
  (ref) => ref.watch(commerceRepositoryProvider).addresses(),
);
final activeAddressProvider = Provider<AsyncValue<AddressModel?>>((ref) {
  final addresses = ref.watch(addressesProvider);
  return addresses.whenData((list) {
    if (list.isEmpty) return null;
    for (final address in list) {
      if (address.isActive) return address;
    }
    return list.first;
  });
});
final paymentMethodsProvider = FutureProvider<List<PaymentMethodModel>>(
  (ref) => ref.watch(commerceRepositoryProvider).paymentMethods(),
);
final currenciesProvider = FutureProvider<List<CurrencyModel>>(
  (ref) => ref.watch(commerceRepositoryProvider).currencies(),
);
final ordersProvider = FutureProvider.autoDispose<List<OrderModel>>(
  (ref) => ref.watch(commerceRepositoryProvider).orders(),
);
final orderDetailsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) => ref.watch(commerceRepositoryProvider).orderDetails(id),
);
final orderTimelineProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, id) => ref.watch(commerceRepositoryProvider).orderTimeline(id),
);
final returnsHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.watch(commerceRepositoryProvider).returnsHistory(),
);
final refundsHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.watch(commerceRepositoryProvider).refundsHistory(),
);
final cartBannersProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(commerceRepositoryProvider).cartBanners(),
);
