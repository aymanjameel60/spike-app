import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/async_state_widgets.dart';

class VendorRegistrationScreen extends ConsumerStatefulWidget {
  const VendorRegistrationScreen({super.key});
  @override ConsumerState<VendorRegistrationScreen> createState()=>_VendorRegistrationScreenState();
}

class _VendorRegistrationScreenState extends ConsumerState<VendorRegistrationScreen>{
  final _form=GlobalKey<FormState>(),_name=TextEditingController(),_phone=TextEditingController(),_email=TextEditingController(),_store=TextEditingController(),_note=TextEditingController();
  bool _busy=false,_prefilled=false;
  @override void dispose(){_name.dispose();_phone.dispose();_email.dispose();_store.dispose();_note.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final user=ref.watch(currentUserProvider).valueOrNull;
    if(!_prefilled&&user!=null){_prefilled=true;_name.text='${user['name']??''}';_phone.text='${user['phone']??''}';final e='${user['email']??''}';if(!e.endsWith('@customer.spike.local'))_email.text=e;}
    return Scaffold(appBar:AppBar(title:const Text('سجّل كتاجر')),body:SafeArea(child:Form(key:_form,child:ListView(padding:const EdgeInsets.all(17),children:[
      const Text('ابدأ البيع على Spike. أرسل بياناتك وسيتم مراجعة الطلب من الإدارة.',style:TextStyle(fontSize:12,height:1.6)),const SizedBox(height:20),
      _field(_name,'الاسم الكامل',required:true),_field(_phone,'رقم الجوال',required:true,keyboard:TextInputType.phone),_field(_email,'البريد الإلكتروني - اختياري',keyboard:TextInputType.emailAddress),_field(_store,'اسم المتجر',required:true),_field(_note,'ملاحظة عن نشاط المتجر',lines:4),
      const SizedBox(height:8),SizedBox(height:50,child:FilledButton(onPressed:_busy?null:_submit,child:Text(_busy?'جاري الإرسال...':'إرسال طلب التسجيل',style:const TextStyle(fontWeight:FontWeight.w800))))
    ]))));
  }
  Widget _field(TextEditingController c,String label,{bool required=false,int lines=1,TextInputType? keyboard})=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextFormField(controller:c,maxLines:lines,keyboardType:keyboard,decoration:InputDecoration(labelText:label),validator:(v)=>required&&(v??'').trim().isEmpty?'هذا الحقل مطلوب':null));
  Future<void> _submit()async{if(!_form.currentState!.validate())return;setState(()=>_busy=true);try{await ref.read(marketplaceRepositoryProvider).registerVendor(applicantName:_name.text,phone:_phone.text,email:_email.text,storeName:_store.text,note:_note.text);if(!mounted)return;showSpikeToast(context,'تم إرسال طلب التسجيل كتاجر');context.pop();}catch(e){if(mounted)showSpikeToast(context,e.toString());}finally{if(mounted)setState(()=>_busy=false);}}
}
