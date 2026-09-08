class ApiConfig {
  static const baseUrl = 'https://spike2.aymanjameel60.deno.net/api/v1';
  static const assetBaseUrl = 'https://spike2.aymanjameel60.deno.net';
  static const mediaBaseUrl = 'https://oshdiaifvwfdbkatagex.supabase.co/storage/v1/object/public/spike-images';
  static const connectTimeout = Duration(seconds: 12);
  static const receiveTimeout = Duration(seconds: 15);

  /// Resolves backend media references the same way the reference frontend
  /// does: absolute URLs pass through, `/uploads/...` serves from the API
  /// host, and relative paths like `stores/...` live in the public media
  /// bucket.
  static String resolveMedia(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    if (value.startsWith('/uploads/')) return assetBaseUrl + value;
    if (RegExp(r'^(products|collections|categories|banners|stores|receipts|avatars|support|misc)/').hasMatch(value)) {
      return '$mediaBaseUrl/$value';
    }
    return value.startsWith('/') ? assetBaseUrl + value : '$assetBaseUrl/$value';
  }
}
