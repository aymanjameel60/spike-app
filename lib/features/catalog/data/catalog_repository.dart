import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import '../../../models/store.dart';

class CatalogRepository {
  CatalogRepository(this._api);

  final ApiClient _api;
  final Map<String, Map<String, dynamic>> _memoryCache = {};

  static const _cachePrefix = 'spike_catalog_cache_v1_';

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
    } catch (_) {
      final memory = _memoryCache[key];
      if (memory != null) return memory;
      if (!persistDisk) return const {};

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw == null || raw.isEmpty) return const {};
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
      return const {};
    }
  }

  Future<List<ProductModel>> products({
    String? categoryId,
    String? collectionId,
  }) async {
    final key = 'products_${categoryId ?? 'all'}_${collectionId ?? 'all'}';
    final data = await _get(
      key,
      '/products',
      persistDisk: false,
      query: {
        if (categoryId != null && categoryId.isNotEmpty) 'category_id': categoryId,
        if (collectionId != null && collectionId.isNotEmpty) 'collection_id': collectionId,
      },
    );
    return (data['products'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ProductModel?> product(String id) async {
    final list = await products();
    for (final product in list) {
      if (product.id == id) return product;
    }
    return null;
  }

  Future<List<StoreModel>> stores() async {
    final data = await _get('stores', '/stores');
    return (data['stores'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => StoreModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<CategoryModel>> categories() async {
    final data = await _get('categories', '/categories');
    return (data['categories'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.enabled)
        .toList();
  }
}
