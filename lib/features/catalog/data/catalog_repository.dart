import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import '../../../models/store.dart';

class ProductPage {
  const ProductPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasNext,
  });

  final List<ProductModel> items;
  final int page;
  final int pageSize;
  final int total;
  final bool hasNext;
}

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

  List<ProductModel> _mapProducts(Object? raw) => (raw as List? ?? const [])
      .whereType<Map>()
      .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
      .toList();

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
    return _mapProducts(data['products']);
  }

  Future<ProductPage> pagedProducts({
    int page = 1,
    int pageSize = 24,
    String? categoryId,
    String? collectionId,
    String? storeId,
    bool offersOnly = false,
    Iterable<String>? ids,
    String? search,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safeSize = pageSize.clamp(10, 100);
    final idList = ids
            ?.map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .take(100)
            .toList() ??
        const <String>[];

    try {
      final data = await _api.get('/products-paged', query: {
        'page': safePage,
        'page_size': safeSize,
        if ((categoryId ?? '').isNotEmpty) 'category_id': categoryId,
        if ((collectionId ?? '').isNotEmpty) 'collection_id': collectionId,
        if ((storeId ?? '').isNotEmpty) 'store_id': storeId,
        if (offersOnly) 'offers_only': 'true',
        if (idList.isNotEmpty) 'ids': idList.join(','),
        if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
      });
      final items = _mapProducts(data['items'] ?? data['products']);
      final meta = data['meta'] is Map
          ? Map<String, dynamic>.from(data['meta'] as Map)
          : const <String, dynamic>{};
      return ProductPage(
        items: items,
        page: int.tryParse('${meta['page'] ?? safePage}') ?? safePage,
        pageSize: int.tryParse('${meta['page_size'] ?? safeSize}') ?? safeSize,
        total: int.tryParse('${meta['total'] ?? items.length}') ?? items.length,
        hasNext: meta['has_next'] == true,
      );
    } catch (_) {
      final fallback = await products(
        categoryId: categoryId,
        collectionId: collectionId,
      );
      var filtered = fallback;
      if ((storeId ?? '').isNotEmpty) {
        filtered = filtered.where((p) => p.storeId == storeId).toList();
      }
      if (offersOnly) {
        filtered = filtered.where((p) {
          final old = p.originalPrice;
          return old != null && old > p.price && p.price > 0;
        }).toList();
      }
      if (idList.isNotEmpty) {
        final wanted = idList.toSet();
        filtered = filtered.where((p) => wanted.contains(p.id)).toList();
      }
      if ((search ?? '').trim().isNotEmpty) {
        final q = search!.trim().toLowerCase();
        filtered = filtered
            .where((p) =>
                p.name.toLowerCase().contains(q) ||
                p.storeName.toLowerCase().contains(q) ||
                (p.categoryName ?? '').toLowerCase().contains(q))
            .toList();
      }
      final start = (safePage - 1) * safeSize;
      if (start >= filtered.length) {
        return ProductPage(
          items: const [],
          page: safePage,
          pageSize: safeSize,
          total: filtered.length,
          hasNext: false,
        );
      }
      final end = (start + safeSize).clamp(0, filtered.length);
      return ProductPage(
        items: filtered.sublist(start, end),
        page: safePage,
        pageSize: safeSize,
        total: filtered.length,
        hasNext: end < filtered.length,
      );
    }
  }

  Future<ProductModel?> product(String id) async {
    final page = await pagedProducts(ids: [id], pageSize: 10);
    for (final product in page.items) {
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
