import '../core/api_config.dart';

class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    this.imageUrl,
    this.bannerUrl,
    this.parentId,
    this.parentName,
    this.hasChildren = false,
    this.enabled = true,
    this.sortOrder = 0,
    this.actionType = 'category',
    this.actionTarget,
    this.showAsMore = false,
  });

  final String id;
  final String name;
  final String? imageUrl;
  final String? bannerUrl;
  final String? parentId;
  final String? parentName;
  final bool hasChildren;
  final bool enabled;
  final int sortOrder;
  final String actionType;
  final String? actionTarget;
  final bool showAsMore;

  bool get isRoot => parentId == null || parentId!.isEmpty;

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
    final resolvedBanner = ApiConfig.resolveMedia('${j['banner_url'] ?? ''}');
    final rawActionType = '${j['action_type'] ?? 'category'}'.trim();
    final rawActionTarget = '${j['action_target'] ?? ''}'.trim();
    final rawParentId = '${j['parent_id'] ?? ''}'.trim();
    final rawParentName = '${j['parent_name'] ?? ''}'.trim();
    final rawName = '${j['name'] ?? ''}'.trim();
    final isMoreName = rawName == 'المزيد' || rawName == 'كل الفئات';

    return CategoryModel(
      id: '${j['id'] ?? ''}',
      name: rawName,
      imageUrl: resolved.isEmpty ? null : resolved,
      bannerUrl: resolvedBanner.isEmpty ? null : resolvedBanner,
      parentId: rawParentId.isEmpty ? null : rawParentId,
      parentName: rawParentName.isEmpty ? null : rawParentName,
      hasChildren: j['has_children'] == true ||
          (int.tryParse('${j['child_count'] ?? 0}') ?? 0) > 0,
      enabled: j['enabled'] != false,
      sortOrder: int.tryParse('${j['sort_order'] ?? 0}') ?? 0,
      actionType: rawActionType.isEmpty ? 'category' : rawActionType,
      actionTarget: rawActionTarget.isEmpty ? null : rawActionTarget,
      showAsMore: j['show_as_more'] == true || isMoreName,
    );
  }
}
