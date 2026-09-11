import '../../../core/network/api_client.dart';
import '../../cart/data/cart_repository.dart';

class CityModel{const CityModel({required this.id,required this.name});final String id,name;factory CityModel.fromJson(Map<String,dynamic> j)=>CityModel(id:'${j['id']??''}',name:'${j['name']??''}');}
class AddressModel{const AddressModel({required this.id,required this.cityId,required this.cityName,required this.label,required this.recipientName,required this.phone,required this.addressLine,required this.googleMapsUrl,required this.isActive});final String id,cityId,cityName,label,recipientName,phone,addressLine,googleMapsUrl;final bool isActive;factory AddressModel.fromJson(Map<String,dynamic> j)=>AddressModel(id:'${j['id']??''}',cityId:'${j['city_id']??''}',cityName:'${j['city_name']??''}',label:'${j['label']??''}',recipientName:'${j['recipient_name']??''}',phone:'${j['phone']??''}',addressLine:'${j['address_line']??''}',googleMapsUrl:'${j['google_maps_url']??''}',isActive:j['is_active']==true);}
class PaymentMethodModel{const PaymentMethodModel({required this.method,required this.instructions});final String method,instructions;factory PaymentMethodModel.fromJson(Map<String,dynamic> j)=>PaymentMethodModel(method:'${j['method']??''}',instructions:'${j['instructions']??''}');String get label=>method=='cod'?'الدفع عند الاستلام':'حوالة مالية';}
class CurrencyModel{const CurrencyModel({required this.code,required this.name,required this.symbol});final String code,name,symbol;factory CurrencyModel.fromJson(Map<String,dynamic> j)=>CurrencyModel(code:'${j['code']??''}'.toUpperCase(),name:'${j['name']??''}',symbol:'${j['symbol']??''}');}
class DeliveryQuote{
  const DeliveryQuote({required this.shippingUsd,required this.shippingYerOld,required this.quotes});final double shippingUsd,shippingYerOld;final List<Map<String,dynamic>> quotes;
  factory DeliveryQuote.fromJson(Map<String,dynamic> j)=>DeliveryQuote(shippingUsd:double.tryParse('${j['shipping_usd']??0}')??0,shippingYerOld:double.tryParse('${j['shipping_yer_old']??0}')??0,quotes:(j['quotes'] as List? ?? const[]).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList());
}
class OrderModel{
  const OrderModel({required this.id,required this.status,required this.paymentMethod,required this.paymentStatus,required this.currencyCode,required this.total,required this.createdAt});
  final String id,status,paymentMethod,paymentStatus,currencyCode,createdAt;final double total;
  factory OrderModel.fromJson(Map<String,dynamic> j)=>OrderModel(id:'${j['id']??''}',status:'${j['status']??''}',paymentMethod:'${j['payment_method']??''}',paymentStatus:'${j['payment_status']??''}',currencyCode:'${j['currency_code']??''}',total:double.tryParse('${j['total']??0}')??0,createdAt:'${j['created_at']??''}');
  String get displayDate{final d=DateTime.tryParse(createdAt)?.toLocal();if(d==null)return '';String two(int v)=>v.toString().padLeft(2,'0');return '${d.year}/${two(d.month)}/${two(d.day)} • ${two(d.hour)}:${two(d.minute)}';}
}

class CommerceRepository{
  CommerceRepository(this._api);final ApiClient _api;
  Future<List<CityModel>> cities()async{final d=await _api.get('/cities');return (d['cities'] as List? ?? const[]).whereType<Map>().map((e)=>CityModel.fromJson(Map<String,dynamic>.from(e))).toList();}
  Future<List<AddressModel>> addresses()async{final d=await _api.get('/addresses',auth:true);return (d['addresses'] as List? ?? const[]).whereType<Map>().map((e)=>AddressModel.fromJson(Map<String,dynamic>.from(e))).toList();}
  Future<AddressModel> createAddress({required String cityId,required String label,required String recipientName,required String phone,required String addressLine,required String googleMapsUrl,required bool isActive})async{final d=await _api.post('/addresses',auth:true,data:{'city_id':cityId,'label':label,'recipient_name':recipientName,'phone':phone,'address_line':addressLine,'google_maps_url':googleMapsUrl,'is_active':isActive});return AddressModel.fromJson(Map<String,dynamic>.from(d['address'] as Map));}
  Future<AddressModel> updateAddress(String id,{required String cityId,required String label,required String recipientName,required String phone,required String addressLine,required String googleMapsUrl,required bool isActive})async{final d=await _api.put('/addresses/$id',auth:true,data:{'city_id':cityId,'label':label,'recipient_name':recipientName,'phone':phone,'address_line':addressLine,'google_maps_url':googleMapsUrl,'is_active':isActive});return AddressModel.fromJson(Map<String,dynamic>.from(d['address'] as Map));}
  Future<void> activateAddress(String id)async{await _api.post('/addresses/$id/activate',auth:true);}Future<void> deleteAddress(String id)async{await _api.delete('/addresses/$id',auth:true);}
  Future<List<PaymentMethodModel>> paymentMethods()async{final d=await _api.get('/payment-methods');return (d['methods'] as List? ?? const[]).whereType<Map>().map((e)=>PaymentMethodModel.fromJson(Map<String,dynamic>.from(e))).toList();}
  Future<List<CurrencyModel>> currencies()async{final d=await _api.get('/currencies');return (d['currencies'] as List? ?? const[]).whereType<Map>().map((e)=>CurrencyModel.fromJson(Map<String,dynamic>.from(e))).toList();}

  Future<DeliveryQuote> quote({required String addressId,required CartSnapshot cart})async=>DeliveryQuote.fromJson(await _api.post('/checkout/delivery-quote-v2',auth:true,data:{
    'address_id':addressId,
    'coupon_code':cart.couponCode,
    'items':cart.items.map((e)=>{'variant_id':e.variantId,'quantity':e.quantity}).toList(),
  }));

  Future<OrderModel> createOrder({required CartSnapshot cart,required String addressId,required String paymentMethod,required String currencyCode})async{
    final d=await _api.post('/checkout/orders-v2',auth:true,data:{
      'address_id':addressId,
      'payment_method':paymentMethod,
      'currency_code':currencyCode,
      'coupon_code':cart.couponCode,
      'items':cart.items.map((e)=>{'variant_id':e.variantId,'quantity':e.quantity}).toList(),
    });
    return OrderModel.fromJson(Map<String,dynamic>.from(d['order'] as Map));
  }

  Future<List<OrderModel>> orders()async{final d=await _api.get('/orders',auth:true);return (d['orders'] as List? ?? const[]).whereType<Map>().map((e)=>OrderModel.fromJson(Map<String,dynamic>.from(e))).toList();}
  Future<Map<String,dynamic>> orderDetails(String id)=>_api.get('/customer-orders/$id',auth:true);
  Future<List<Map<String,dynamic>>> orderTimeline(String id)async{final d=await _api.get('/customer-orders/$id/timeline',auth:true);return (d['timeline'] as List? ?? const[]).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();}
  Future<void> uploadReceipt(String orderId,String filePath)async{final up=await _api.uploadFile('/uploads/receipt',filePath:filePath),ref='${up['key']??up['path']??up['url']??''}';if(ref.isEmpty)throw const ApiException('تعذر رفع السند');await _api.post('/customer-media/orders/$orderId/receipt',auth:true,data:{'receipt_url':ref});}
  Future<void> requestReturn({required String orderItemId,required int quantity,required String reason})async{await _api.post('/customer-orders/returns',auth:true,data:{'order_item_id':orderItemId,'quantity':quantity,'reason':reason});}
  Future<List<Map<String,dynamic>>> returnsHistory()async{final d=await _api.get('/customer-orders/returns/list',auth:true);return (d['returns'] as List? ?? const[]).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();}
  Future<List<Map<String,dynamic>>> refundsHistory()async{final d=await _api.get('/refunds',auth:true);return (d['refunds'] as List? ?? const[]).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();}
  Future<List<Map<String,dynamic>>> cartBanners()async{final d=await _api.get('/banners',query:{'placement':'cart'});return (d['banners'] as List? ?? const[]).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();}
}
