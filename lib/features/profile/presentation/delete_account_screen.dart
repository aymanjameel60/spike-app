import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});
  @override ConsumerState<DeleteAccountScreen> createState()=>_DeleteAccountScreenState();
}
class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen>{
  bool _busy=false;
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('حذف الحساب')),body:SafeArea(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Spacer(),const Icon(Icons.warning_amber_rounded,size:60,color:spikeRed),const SizedBox(height:18),const Text('هل أنت متأكد من حذف الحساب؟',textAlign:TextAlign.center,style:TextStyle(fontSize:20,fontWeight:FontWeight.w800)),const SizedBox(height:10),const Text('سيتم تعطيل حسابك نهائياً وإخفاء بياناته الشخصية. ستبقى سجلات الطلبات المالية اللازمة للنظام محفوظة بدون إتاحة الحساب لتسجيل الدخول.',textAlign:TextAlign.center,style:TextStyle(fontSize:11,height:1.7,color:spikeMuted)),const Spacer(),
    SizedBox(height:50,child:FilledButton(style:FilledButton.styleFrom(backgroundColor:spikeRed),onPressed:_busy?null:_delete,child:Text(_busy?'جاري الحذف...':'نعم، حذف الحساب',style:const TextStyle(fontWeight:FontWeight.w800)))),const SizedBox(height:10),SizedBox(height:48,child:OutlinedButton(onPressed:_busy?null:()=>context.pop(),child:const Text('إلغاء')))
  ]))));
  Future<void> _delete()async{setState(()=>_busy=true);try{await ref.read(marketplaceRepositoryProvider).deleteAccount();await ref.read(authRepositoryProvider).logout();ref.invalidate(currentUserProvider);ref.invalidate(hasSessionProvider);if(mounted){showSpikeToast(context,'تم حذف الحساب');context.go('/');}}catch(e){if(mounted)showSpikeToast(context,e.toString());}finally{if(mounted)setState(()=>_busy=false);}}
}
