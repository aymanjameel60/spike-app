class ApiConfig {
  static const baseUrl = 'https://spike2.aymanjameel60.deno.net/api/v1';
  static const assetBaseUrl = 'https://spike2.aymanjameel60.deno.net';
  static const customerWebBaseUrl = 'https://spikrfront-25.aymanjameel60.deno.net';
  static const connectTimeout = Duration(seconds: 12);
  static const receiveTimeout = Duration(seconds: 15);

  static String _mediaPublicBaseUrl = '';

  static String get mediaConfigUrl => '$baseUrl/media/config';

  /// Configures the provider-neutral media resolver from the backend contract.
  ///
  /// The backend remains the source of truth for the active storage provider;
  /// Flutter only receives the public base URL and never stores provider
  /// credentials or hardcoded provider-specific URLs.
  static bool configureMediaContract({
    required Object? storageValue,
    required Object? publicBaseUrl,
  }) {
    final storage = '${storageValue ?? ''}'.trim();
    final publicBase = '${publicBaseUrl ?? ''}'.trim().replaceFirst(
          RegExp(r'/+$'),
          '',
        );
    if (storage != 'object_key' || publicBase.isEmpty) return false;
    final uri = Uri.tryParse(publicBase);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return false;
    }
    _mediaPublicBaseUrl = publicBase;
    return true;
  }

  static bool get hasMediaContract => _mediaPublicBaseUrl.isNotEmpty;

  static bool _isManagedMediaKey(String value) => RegExp(
        r'^(products|collections|categories|banners|stores|receipts|avatars|support|misc)/',
      ).hasMatch(value);

  static String _encodeObjectKey(String value) => value
      .split('/')
      .where((part) => part.isNotEmpty)
      .map(Uri.encodeComponent)
      .join('/');

  /// Provider-neutral media resolver. Persisted media values are object keys.
  /// The preferred path mirrors Customer Web: `/media/config` supplies the
  /// active public base URL. If that bootstrap is unavailable, the supported
  /// backend `/media/file/<key>` redirect remains as a safe fallback.
  /// Legacy absolute URLs and `/uploads/...` remain readable.
  static String resolveMedia(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/uploads/')) return assetBaseUrl + value;

    if (_isManagedMediaKey(value)) {
      final key = _encodeObjectKey(value);
      if (_mediaPublicBaseUrl.isNotEmpty) {
        return '$_mediaPublicBaseUrl/$key';
      }
      return '$baseUrl/media/file/$key';
    }

    return value.startsWith('/') ? assetBaseUrl + value : '$assetBaseUrl/$value';
  }

  static String referralLink(String code) =>
      '$customerWebBaseUrl/?ref=${Uri.encodeQueryComponent(code.trim().toUpperCase())}&signup=1';
}
