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
  List<CategoryModel>? _categoriesCache;

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

  List<ProductModel> _mapProducts(Object? raw) => (raw as List? ?? const [])
      .whereType<Map>()
      .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  Future<(String?, String?)> _resolveProductDestination(
    String? categoryId,
    String? collectionId,
  ) async {
    if ((collectionId ?? '').isNotEmpty || (categoryId ?? '').isEmpty) {
      return (categoryId, collectionId);
    }

    final categories = await this.categories();
    var currentId = categoryId!.trim();
    final visited = <String>{};

    for (var depth = 0; depth < 12; depth++) {
      if (!visited.add(currentId)) break;

      CategoryModel? current;
      for (final category in categories) {
        if (category.id == currentId) {
          current = category;
          break;
        }
      }
      if (current == null) break;

      final collectionTarget = current.effectiveCollectionId;
      if (collectionTarget != null) return (null, collectionTarget);

      final categoryTarget = current.effectiveCategoryId;
      if (categoryTarget == null || categoryTarget == currentId) {
        return (currentId, null);
      }
      currentId = categoryTarget;
    }

    return (currentId, null);
  }

  Future<Set<String>> categoryTreeIds(String rootId) async {
    final all = await categories();
    final result = <String>{rootId};
    var changed = true;
    while (changed) {
      changed = false;
      for (final category in all) {
        if (category.parentId != null &&
            result.contains(category.parentId) &&
            result.add(category.id)) {
          changed = true;
        }
      }
    }
    return result;
  }

  Future<List<ProductModel>> products({
    String? categoryId,
    String? collectionId,
  }) async {
    final destination = await _resolveProductDestination(categoryId, collectionId);
    final resolvedCategoryId = destination.$1;
    final resolvedCollectionId = destination.$2;
    final key =
        'products_${resolvedCategoryId ?? 'all'}_${resolvedCollectionId ?? 'all'}';
    final data = await _get(
      key,
      '/products',
      persistDisk: false,
      query: {
        if ((resolvedCategoryId ?? '').isNotEmpty)
          'category_id': resolvedCategoryId,
        if ((resolvedCollectionId ?? '').isNotEmpty)
          'collection_id': resolvedCollectionId,
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
    bool includeDescendants = false,
    bool offersOnly = false,
    Iterable<String>? ids,
    String? search,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safeSize = pageSize.clamp(10, 100).toInt();
    final idList = ids
            ?.map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .take(100)
            .toList() ??
        const <String>[];
    final destination = await _resolveProductDestination(categoryId, collectionId);
    final resolvedCategoryId = destination.$1;
    final resolvedCollectionId = destination.$2;

    try {
      final data = await _api.get('/products-paged', query: {
        'page': safePage,
        'page_size': safeSize,
        if ((resolvedCategoryId ?? '').isNotEmpty)
          'category_id': resolvedCategoryId,
        if ((resolvedCategoryId ?? '').isNotEmpty && includeDescendants)
          'include_descendants': 'true',
        if ((resolvedCollectionId ?? '').isNotEmpty)
          'collection_id': resolvedCollectionId,
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
      List<ProductModel> fallback;
      if (includeDescendants && (resolvedCategoryId ?? '').isNotEmpty) {
        final all = await products();
        final allowed = await categoryTreeIds(resolvedCategoryId!);
        fallback = all
            .where((product) =>
                product.categoryId != null && allowed.contains(product.categoryId))
            .toList();
      } else {
        fallback = await products(
          categoryId: categoryId,
          collectionId: collectionId,
        );
      }
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
      final end = (start + safeSize).clamp(0, filtered.length).toInt();
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
    final cached = _categoriesCache;
    if (cached != null) return cached;
    final data = await _get('categories', '/categories');
    final result = (data['categories'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.enabled)
        .toList();
    _categoriesCache = result;
    return result;
  }
}
