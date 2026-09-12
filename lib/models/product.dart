import '../core/api_config.dart';

String? _absoluteImage(Object? value) {
  final resolved = ApiConfig.resolveMedia('${value ?? ''}');
  return resolved.isEmpty ? null : resolved;
}

class ProductVariant {
  const ProductVariant({required this.id, required this.title, required this.price, this.originalPrice, required this.stock, this.currency = 'USD'});
  final String id;
  final String title;
  final double price;
  final double? originalPrice;
  final int stock;
  final String currency;

  factory ProductVariant.fromJson(Map<String, dynamic> j) => ProductVariant(
    id: '${j['id'] ?? ''}',
    title: '${j['title'] ?? 'Default'}',
    price: double.tryParse('${j['price_usd'] ?? j['price'] ?? 0}') ?? 0,
    originalPrice: (j['original_price_usd'] ?? j['original_price']) == null ? null : double.tryParse('${j['original_price_usd'] ?? j['original_price']}'),
    stock: int.tryParse('${j['stock'] ?? 0}') ?? 0,
    currency: '${j['currency'] ?? j['currency_code'] ?? 'USD'}'.toUpperCase(),
  );
}

class ProductModel {
  const ProductModel({required this.id, required this.name, required this.storeName, this.storeId, this.description, this.categoryId, this.categoryName, this.returnable = false, this.imageUrl, this.images = const [], this.createdAt, required this.rating, required this.reviewCount, required this.variants});
  final String id;
  final String name;
  final String storeName;
  final String? storeId;
  final String? description;
  final String? categoryId;
  final String? categoryName;
  final bool returnable;
  final String? imageUrl;
  final List<String> images;
  final DateTime? createdAt;
  final double rating;
  final int reviewCount;
  final List<ProductVariant> variants;

  double get price => variants.where((v) => v.price > 0).fold<double>(0, (min, v) => min == 0 || v.price < min ? v.price : min);
  ProductVariant? get cheapestVariant {
    final list = variants.where((v) => v.price > 0).toList()..sort((a, b) => a.price.compareTo(b.price));
    return list.isEmpty ? (variants.isEmpty ? null : variants.first) : list.first;
  }
  double? get originalPrice => cheapestVariant?.originalPrice;
  String get currency => cheapestVariant?.currency ?? 'USD';
  bool get purchasable => variants.any((v) => v.id.isNotEmpty && v.stock > 0);

  factory ProductModel.fromJson(Map<String, dynamic> j) {
    final rawImages = (j['images'] as List? ?? const []);
    final images = rawImages.map((e) { if (e is Map) return _absoluteImage(e['url']); return _absoluteImage(e); }).whereType<String>().toList();
    final variants = (j['variants'] as List? ?? const []).whereType<Map>().map((e) => ProductVariant.fromJson(Map<String, dynamic>.from(e))).toList();
    return ProductModel(
      id: '${j['id'] ?? ''}',
      name: '${j['name'] ?? j['title'] ?? ''}',
      storeName: '${j['store_name'] ?? j['store']?['name'] ?? 'Spike'}',
      storeId: (j['store_id'] ?? j['store']?['id'])?.toString(),
      description: j['description']?.toString(),
      categoryId: (j['category_id'] ?? j['category']?['id'])?.toString(),
      categoryName: j['category_name']?.toString(),
      returnable: j['returnable'] == true,
      imageUrl: images.isEmpty ? _absoluteImage(j['image_url']) : images.first,
      images: images,
      createdAt: DateTime.tryParse('${j['created_at'] ?? j['createdAt'] ?? ''}'),
      rating: double.tryParse('${j['review_average'] ?? j['rating'] ?? 0}') ?? 0,
      reviewCount: int.tryParse('${j['review_count'] ?? 0}') ?? 0,
      variants: variants,
    );
  }
}
