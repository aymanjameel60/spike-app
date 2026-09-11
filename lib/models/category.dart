import '../core/api_config.dart';

class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    this.imageUrl,
    this.enabled = true,
    this.sortOrder = 0,
    this.actionType = 'category',
    this.actionTarget,
    this.showAsMore = false,
  });

  final String id;
  final String name;
  final String? imageUrl;
  final bool enabled;
  final int sortOrder;
  final String actionType;
  final String? actionTarget;
  final bool showAsMore;

  String? get effectiveCategoryId {
    if (actionType != 'category') return null;
    final target = actionTarget?.trim() ?? '';
    return target.isNotEmpty ? target : id;
  }

  String? get effectiveCollectionId {
    if (actionType != 'collection') return null;
    final target = actionTarget?.trim() ?? '';
    return target.isNotEmpty ? target : null;
  }

  bool get opensProducts =>
      effectiveCategoryId != null || effectiveCollectionId != null;

  factory CategoryModel.fromJson(Map<String, dynamic> j) {
    final resolved = ApiConfig.resolveMedia('${j['image_url'] ?? ''}');
    final rawActionType = '${j['action_type'] ?? 'category'}'.trim();
    final rawActionTarget = '${j['action_target'] ?? ''}'.trim();

    return CategoryModel(
      id: '${j['id'] ?? ''}',
      name: '${j['name'] ?? ''}',
      imageUrl: resolved.isEmpty ? null : resolved,
      enabled: j['enabled'] != false,
      sortOrder: int.tryParse('${j['sort_order'] ?? 0}') ?? 0,
      actionType: rawActionType.isEmpty ? 'category' : rawActionType,
      actionTarget: rawActionTarget.isEmpty ? null : rawActionTarget,
      showAsMore: j['show_as_more'] == true,
    );
  }
}
