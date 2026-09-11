import '../../../core/network/api_client.dart';

class MarketplaceRepository {
  MarketplaceRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> wallet() => _api.get('/wallet/me', auth: true);

  Future<void> registerVendor({
    required String applicantName,
    required String phone,
    required String storeName,
    String email = '',
    String note = '',
  }) async {
    await _api.post('/vendor-registration', data: {
      'applicant_name': applicantName.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'store_name': storeName.trim(),
      'note': note.trim(),
    });
  }

  Future<void> deleteAccount() => _api.delete('/account/me', auth: true);
}
