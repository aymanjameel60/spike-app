import '../core/api_config.dart';

class CategoryModel {
  const CategoryModel({required this.id, required this.name, this.imageUrl, this.enabled = true, this.sortOrder = 0});
  final String id;
  final String name;
  final String? imageUrl;
  final bool enabled;
  final int sortOrder;

  factory CategoryModel.fromJson(Map<String, dynamic> j) {
    final resolved = ApiConfig.resolveMedia('${j['image_url'] ?? ''}');
    return CategoryModel(
      id: '${j['id'] ?? ''}',
      name: '${j['name'] ?? ''}',
      imageUrl: resolved.isEmpty ? null : resolved,
      enabled: j['enabled'] != false,
      sortOrder: int.tryParse('${j['sort_order'] ?? 0}') ?? 0,
    );
  }
}
