class HomeSectionModel {
  const HomeSectionModel({
    required this.id,
    required this.title,
    required this.contentType,
    required this.sourceType,
    required this.referenceId,
    required this.showAll,
    required this.showAllTargetType,
    required this.showAllTargetId,
    required this.sortOrder,
    required this.items,
  });

  final String id;
  final String title;
  final String contentType;
  final String sourceType;
  final String? referenceId;
  final bool showAll;
  final String showAllTargetType;
  final String? showAllTargetId;
  final int sortOrder;
  final List<Map<String, dynamic>> items;

  factory HomeSectionModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    final reference = '${json['reference_id'] ?? ''}'.trim();
    final targetId = '${json['show_all_target_id'] ?? ''}'.trim();
    return HomeSectionModel(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}'.trim(),
      contentType: '${json['content_type'] ?? 'products'}'.trim().toLowerCase(),
      sourceType: '${json['source_type'] ?? 'latest'}'.trim().toLowerCase(),
      referenceId: reference.isEmpty ? null : reference,
      showAll: json['show_all'] != false,
      showAllTargetType: '${json['show_all_target_type'] ?? 'section'}'.trim().toLowerCase(),
      showAllTargetId: targetId.isEmpty ? null : targetId,
      sortOrder: int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
      items: rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }
}
