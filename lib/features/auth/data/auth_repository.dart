import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

class AuthRepository{
  AuthRepository(this._api,this._tokens);final ApiClient _api;final TokenStorage _tokens;

  Future<Map<String,dynamic>> loginPhone({required String phone,required String password})async{
    final d=await _api.post('/auth/login-phone',data:{'phone':phone.replaceAll(RegExp(r'\D'),'').trim(),'password':password});
    final token='${d['token']??''}';
    if(token.isEmpty)throw const ApiException('تعذر حفظ جلسة تسجيل الدخول');
    final user=Map<String,dynamic>.from(d['user'] as Map? ?? const {});
    await _tokens.writeToken(token);
    if(user.isNotEmpty)await _tokens.writeCachedUser(user);
    return user;
  }

  Future<Map<String,dynamic>> registerPhone({
    required String name,
    required String phone,
    required String password,
    required String gender,
    required String country,
    required String governorate,
    String referralCode='',
  })async{
    final normalized=phone.replaceAll(RegExp(r'\D'),'').trim();
    final d=await _api.post('/auth/register-phone',data:{
      'name':name.trim(),
      'phone':normalized,
      'password':password,
      'gender':gender,
      'country':country,
      'governorate':governorate,
    });
    final token='${d['token']??''}';
    if(token.isEmpty)throw const ApiException('تعذر حفظ جلسة الحساب');
    final user=Map<String,dynamic>.from(d['user'] as Map? ?? const {});
    await _tokens.writeToken(token);
    if(user.isNotEmpty)await _tokens.writeCachedUser(user);
    final code=referralCode.trim().toUpperCase();
    if(code.isNotEmpty){
      try{await _api.post('/share-win/accept',auth:true,data:{'code':code});}on ApiException catch(e){
        if(![400,404,409].contains(e.statusCode))rethrow;
      }
    }
    return user;
  }

  Future<Map<String,dynamic>?> me()async{
    final token=await _tokens.readToken();
    if(token==null||token.isEmpty)return null;
    try{
      final d=await _api.get('/me',auth:true),u=d['user'];
      final user=u is Map?Map<String,dynamic>.from(u):null;
      if(user!=null&&user.isNotEmpty)await _tokens.writeCachedUser(user);
      return user;
    }on ApiException catch(e){
      if(e.statusCode==401){await _tokens.clearToken();return null;}
      return _tokens.readCachedUser();
    }
  }

  Future<Map<String,dynamic>> updateProfile({required String name})async{
    final d=await _api.put('/profile',auth:true,data:{'name':name.trim()});
    final user=Map<String,dynamic>.from(d['user'] as Map? ?? const {});
    if(user.isNotEmpty)await _tokens.writeCachedUser(user);
    return user;
  }

  Future<Map<String,dynamic>> uploadAvatar(String filePath)async{
    final uploaded=await _api.uploadFile('/uploads/avatar',filePath:filePath),ref='${uploaded['key']??uploaded['path']??uploaded['url']??''}';
    if(ref.isEmpty)throw const ApiException('تعذر رفع الصورة');
    final d=await _api.put('/customer-media/profile/avatar',auth:true,data:{'avatar_url':ref});
    final user=Map<String,dynamic>.from(d['user'] as Map? ?? const {});
    if(user.isNotEmpty)await _tokens.writeCachedUser(user);
    return user;
  }

  Future<void> requestPhoneChange(String phone)async{await _api.post('/profile/phone/request',auth:true,data:{'phone':phone.trim()});}

  Future<Map<String,dynamic>> verifyPhoneChange(String code)async{
    final d=await _api.post('/profile/phone/verify',auth:true,data:{'code':code});
    final user=Map<String,dynamic>.from(d['user'] as Map? ?? const {});
    if(user.isNotEmpty)await _tokens.writeCachedUser(user);
    return user;
  }

  Future<void> requestPasswordReset(String email)async{await _api.post('/auth/password-reset/request',data:{'email':email.trim()});}
  Future<void> confirmPasswordReset({required String email,required String code,required String password})async{await _api.post('/auth/password-reset/confirm',data:{'email':email.trim(),'code':code.trim(),'password':password});}
  Future<void> logout()=>_tokens.clearToken();
}
