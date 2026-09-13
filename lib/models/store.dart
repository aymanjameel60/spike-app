import '../core/api_config.dart';

class StoreModel {
  const StoreModel({
    required this.id,
    required this.name,
    this.logoUrl,
    this.bannerUrl,
    this.categoryName,
    this.rating = 0,
    this.reviewCount = 0,
    this.isVerified = false,
  });

  final String id;
  final String name;
  final String? logoUrl;
  final String? bannerUrl;
  final String? categoryName;
  final double rating;
  final int reviewCount;
  final bool isVerified;

  static String? _asset(dynamic value) {
    final resolved = ApiConfig.resolveMedia('${value ?? ''}');
    return resolved.isEmpty ? null : resolved;
  }

  factory StoreModel.fromJson(Map<String, dynamic> j) {
    return StoreModel(
      id: '${j['id'] ?? ''}',
      name: '${j['name'] ?? ''}',
      logoUrl: _asset(j['logo_url'] ?? j['logo']),
      bannerUrl: _asset(j['banner_url'] ?? j['banner'] ?? j['cover_url']),
      categoryName: '${j['category_name'] ?? j['category'] ?? ''}'.trim().isEmpty
          ? null
          : '${j['category_name'] ?? j['category']}',
      rating: double.tryParse('${j['review_average'] ?? j['rating'] ?? 0}') ?? 0,
      reviewCount: int.tryParse('${j['review_count'] ?? j['reviews'] ?? 0}') ?? 0,
      isVerified: j['is_verified'] == true || j['isVerified'] == true,
    );
  }
}
