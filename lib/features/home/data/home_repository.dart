import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/api_config.dart';
import '../../../models/banner_item.dart';
import '../../../models/category.dart';
import '../../../models/collection.dart';
import '../../../models/product.dart';
import '../../../models/store.dart';

class HomeData {
  const HomeData({required this.categories, required this.products, required this.bestSellers, required this.stores, required this.banners, required this.collections});
  final List<CategoryModel> categories;
  final List<ProductModel> products;
  final List<ProductModel> bestSellers;
  final List<StoreModel> stores;
  final List<BannerItem> banners;
  final List<CollectionModel> collections;
}

class HomeRepository {
  HomeRepository(this._api);
  final ApiClient _api;

  static const _cachePrefix = 'spike_home_cache_v1_';

  Future<Map<String, dynamic>> _cachedGet(
    String key,
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_cachePrefix$key';
    try {
      final data = await _api.get(path, query: query);
      await prefs.setString(cacheKey, jsonEncode(data));
      return data;
    } catch (_) {
      final raw = prefs.getString(cacheKey);
      if (raw == null || raw.isEmpty) return const {};
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        await prefs.remove(cacheKey);
      }
      return const {};
    }
  }

  Future<String?> brandingLogo() async {
    final data = await _cachedGet('branding', '/branding');
    final value = '${data['app_logo_url'] ?? data['logo_url'] ?? ''}'.trim();
    if (value.isEmpty) return null;
    return ApiConfig.resolveMedia(value);
  }

  Future<HomeData> load() async {
    final results = await Future.wait<Map<String, dynamic>>([
      _cachedGet('categories', '/categories'),
      _cachedGet('products', '/products'),
      _cachedGet('stores', '/stores'),
      _cachedGet('sections', '/home-sections'),
      _cachedGet('banners', '/banners', query: {'placement': 'home'}),
      _cachedGet('best_sellers', '/best-sellers', query: {'limit': '12'}),
    ]);

    final categoriesRaw = (results[0]['categories'] as List? ?? const []);
    final productsRaw = (results[1]['products'] as List? ?? const []);
    final storesRaw = (results[2]['stores'] as List? ?? const []);
    final home = results[3];
    final categories = categoriesRaw.whereType<Map>().map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e))).where((e) => e.enabled).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final products = productsRaw.whereType<Map>().map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e))).toList();
    final bestSellers = (results[5]['products'] as List? ?? const []).whereType<Map>().map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e))).toList();
    final stores = storesRaw.whereType<Map>().map((e) => StoreModel.fromJson(Map<String, dynamic>.from(e))).toList();
    final banners = (results[4]['banners'] as List? ?? const []).whereType<Map>().map((e) => BannerItem.fromJson(Map<String, dynamic>.from(e))).where((e) => e.imageUrl.isNotEmpty).toList();
    final collections = (home['spike_collections'] as List? ?? const []).whereType<Map>().where((e) => e['enabled'] != false).map((e) => CollectionModel.fromJson(Map<String, dynamic>.from(e))).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return HomeData(categories: categories, products: products, bestSellers: bestSellers, stores: stores, banners: banners, collections: collections);
  }
}
