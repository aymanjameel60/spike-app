class HomeSectionModel {
  const HomeSectionModel({
    required this.id,
    required this.title,
    required this.contentType,
    required this.sourceType,
    required this.showAll,
    required this.sortOrder,
    required this.items,
  });

  final String id;
  final String title;
  final String contentType;
  final String sourceType;
  final bool showAll;
  final int sortOrder;
  final List<Map<String, dynamic>> items;

  factory HomeSectionModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    return HomeSectionModel(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}'.trim(),
      contentType: '${json['content_type'] ?? 'products'}'.trim().toLowerCase(),
      sourceType: '${json['source_type'] ?? 'latest'}'.trim().toLowerCase(),
      showAll: json['show_all'] != false,
      sortOrder: int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
      items: rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }
}
