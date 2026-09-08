import '../core/api_config.dart';

class BannerItem {
  const BannerItem({
    required this.id,
    required this.imageUrl,
    required this.actionType,
    required this.target,
    this.targetUrl = '',
    this.countdown = false,
    this.endsAt,
  });

  final String id;
  final String imageUrl;
  final String actionType;
  final String target;
  final String targetUrl;
  final bool countdown;
  final DateTime? endsAt;

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    final rawEnd='${json['ends_at']??''}'.trim();
    return BannerItem(
      id: '${json['id'] ?? ''}',
      imageUrl: _imageUrl(json),
      actionType: '${json['action_type'] ?? json['target_type'] ?? 'none'}',
      target: '${json['target'] ?? json['target_id'] ?? ''}',
      targetUrl: '${json['target_url'] ?? ''}',
      countdown: json['countdown']==true,
      endsAt: rawEnd.isEmpty?null:DateTime.tryParse(rawEnd),
    );
  }
}

String _imageUrl(Map<String, dynamic> json) => ApiConfig.resolveMedia('${json['image_url'] ?? json['image'] ?? json['mobile_image_url'] ?? json['desktop_image_url'] ?? ''}');
