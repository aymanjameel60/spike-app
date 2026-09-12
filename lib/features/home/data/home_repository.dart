import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../models/banner_item.dart';
import '../../../models/category.dart';
import '../../../models/collection.dart';
import '../../../models/home_section.dart';
import '../../../models/product.dart';
import '../../../models/store.dart';

class HomeData {
  const HomeData({
    required this.categories,
    required this.allCategories,
    required this.products,
    required this.bestSellers,
    required this.stores,
    required this.banners,
    required this.collections,
    required this.sections,
  });

  final List<CategoryModel> categories;
  final List<CategoryModel> allCategories;
  final List<ProductModel> products;
  final List<ProductModel> bestSellers;
  final List<StoreModel> stores;
  final List<BannerItem> banners;
  final List<CollectionModel> collections;
  final List<HomeSectionModel> sections;
}

class HomeRepository {
  HomeRepository(this._api);

  final ApiClient _api;
  final Map<String, Map<String, dynamic>> _memoryCache = {};

  static const _cachePrefix = 'spike_home_cache_v1_';

  Future<Map<String, dynamic>> _get(
    String key,
    String path, {
    Map<String, dynamic>? query,
    bool persistDisk = true,
  }) async {
    final cacheKey = '$_cachePrefix$key';
    try {
      final data = await _api.get(path, query: query);
      _memoryCache[key] = data;
      if (persistDisk) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(data));
      }
      return data;
    } catch (error) {
      final memory = _memoryCache[key];
      if (memory != null) return memory;
      if (!persistDisk) rethrow;

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw == null || raw.isEmpty) rethrow;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final data = Map<String, dynamic>.from(decoded);
          _memoryCache[key] = data;
          return data;
        }
      } catch (_) {
        await prefs.remove(cacheKey);
      }
      throw error;
    }
  }

  Future<Map<String, dynamic>> _homeProducts() async {
    try {
      final data = await _api.get('/products-paged', query: {
        'page': 1,
        'page_size': 24,
      });
      return {
        'products': data['items'] ?? data['products'] ?? const [],
      };
    } catch (_) {
      return _get('products', '/products', persistDisk: false);
    }
  }

  Future<String?> brandingLogo() async {
    final data = await _get('branding', '/branding');
    final value = '${data['app_logo_url'] ?? data['logo_url'] ?? ''}'.trim();
    if (value.isEmpty) return null;
    return ApiConfig.resolveMedia(value);
  }

  Future<List<BannerItem>> popupBanners() async {
    final data = await _api.get('/banners', query: {'placement': 'popup'});
    return (data['banners'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => BannerItem.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.imageUrl.isNotEmpty)
        .toList();
  }

  Future<HomeSectionModel> section(String id) async {
    final data = await _api.get('/home-sections/$id');
    final raw = data['section'];
    if (raw is! Map) {
      throw const FormatException('استجابة القسم من الخادم غير صالحة');
    }
    final section = Map<String, dynamic>.from(raw);
    section['items'] = data['items'] ?? section['items'] ?? const [];
    return HomeSectionModel.fromJson(section);
  }

  Future<HomeData> load() async {
    final results = await Future.wait<Map<String, dynamic>>([
      _get('categories', '/categories'),
      _homeProducts(),
      _get('stores', '/stores'),
      _get('collections', '/collections'),
      _get('sections', '/home-sections'),
      _get('banners', '/banners', query: {'placement': 'home'}),
      _get(
        'best_sellers',
        '/best-sellers',
        query: {'limit': '12'},
        persistDisk: false,
      ),
    ]);

    final categoriesRaw = results[0]['categories'] as List? ?? const [];
    final productsRaw = results[1]['products'] as List? ?? const [];
    final storesRaw = results[2]['stores'] as List? ?? const [];
    final collectionsRaw = results[3]['collections'] as List? ?? const [];
    final home = results[4];

    // Keep the backend order as the only category ordering source. The
    // configurable "more / all categories" record is a navigation tile: it
    // is pinned to Home slot 8, while the All Categories screen receives only
    // real categories and therefore never renders that navigation-only tile.
    final enabledCategories = categoriesRaw
        .whereType<Map>()
        .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.enabled)
        .toList();
    final allCategories = enabledCategories
        .where((e) => !e.showAsMore && e.actionType != 'all_categories')
        .toList();
    CategoryModel? moreCategory;
    for (final category in enabledCategories) {
      if (category.showAsMore || category.actionType == 'all_categories') {
        moreCategory = category;
        break;
      }
    }
    final categories = <CategoryModel>[
      ...allCategories.take(moreCategory == null ? 8 : 7),
      if (moreCategory != null) moreCategory,
    ];

    final products = productsRaw
        .whereType<Map>()
        .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final bestSellers = (results[6]['products'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final stores = storesRaw
        .whereType<Map>()
        .map((e) => StoreModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final collections = collectionsRaw
        .whereType<Map>()
        .map((e) => CollectionModel.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final banners = (results[5]['banners'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => BannerItem.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.imageUrl.isNotEmpty)
        .toList();

    final sections = (home['sections'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => HomeSectionModel.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.title.isNotEmpty)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return HomeData(
      categories: categories,
      allCategories: allCategories,
      products: products,
      bestSellers: bestSellers,
      stores: stores,
      banners: banners,
      collections: collections,
      sections: sections,
    );
  }
}
