class ApiConfig {
  static const baseUrl = 'https://spike2.aymanjameel60.deno.net/api/v1';
  static const assetBaseUrl = 'https://spike2.aymanjameel60.deno.net';
  static const customerWebBaseUrl = 'https://spikrfront-25.aymanjameel60.deno.net';
  static const connectTimeout = Duration(seconds: 12);
  static const receiveTimeout = Duration(seconds: 15);

  /// Provider-neutral media resolver. Persisted media values are object keys.
  /// The backend owns provider selection and redirects `/media/file/<key>` to
  /// the active storage provider. Legacy absolute URLs and `/uploads/...`
  /// remain readable for backwards compatibility.
  static String resolveMedia(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    if (value.startsWith('/uploads/')) return assetBaseUrl + value;
    if (RegExp(r'^(products|collections|categories|banners|stores|receipts|avatars|support|misc)/').hasMatch(value)) {
      return '$baseUrl/media/file/${Uri.encodeComponent(value)}';
    }
    return value.startsWith('/') ? assetBaseUrl + value : '$assetBaseUrl/$value';
  }

  static String referralLink(String code) =>
      '$customerWebBaseUrl/?ref=${Uri.encodeQueryComponent(code.trim().toUpperCase())}&signup=1';
}
