import '../../../core/network/api_client.dart';

class ShareWinRepository {
  ShareWinRepository(this._api);
  final ApiClient _api;

  Future<Map<String,dynamic>> publicConfig() async {
    final d=await _api.get('/share-win/public');
    return Map<String,dynamic>.from(d);
  }

  Future<Map<String,dynamic>> me() async {
    final d=await _api.get('/share-win/me',auth:true);
    return Map<String,dynamic>.from(d);
  }

  Future<Map<String,dynamic>> accept(String code) async {
    final d=await _api.post('/share-win/accept',auth:true,data:{'code':code.trim().toUpperCase()});
    return Map<String,dynamic>.from(d);
  }
}
