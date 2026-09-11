import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, required this.mode, this.afterLoginRoute = '/profile', this.referralCode = ''});
  final String mode;
  final String afterLoginRoute;
  final String referralCode;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _name=TextEditingController(),_phone=TextEditingController(),_password=TextEditingController(),_referral=TextEditingController();
  bool _busy=false;
  String _gender='',_governorate='';
  bool get signup=>widget.mode=='signup';
  static const governorates=['أمانة العاصمة','صنعاء','عدن','تعز','الحديدة','إب','ذمار','حضرموت','لحج','أبين','الضالع','البيضاء','مأرب','الجوف','صعدة','حجة','المحويت','عمران','ريمة','شبوة','المهرة','سقطرى'];

  @override
  void initState(){super.initState();_referral.text=widget.referralCode.trim().toUpperCase();}
  @override
  void dispose(){_name.dispose();_phone.dispose();_password.dispose();_referral.dispose();super.dispose();}

  Future<void> _submit()async{
    if(_busy)return;
    final phone=_phone.text.replaceAll(RegExp(r'\D'),'');
    if(phone.isEmpty||_password.text.isEmpty||(signup&&_name.text.trim().isEmpty)){showSpikeToast(context,'أكمل الحقول المطلوبة');return;}
    if(signup&&_password.text.length<8){showSpikeToast(context,'يجب أن لا تقل كلمة المرور عن 8 أحرف');return;}
    if(signup&&_gender.isEmpty){showSpikeToast(context,'اختر نوع الجنس');return;}
    if(signup&&_governorate.isEmpty){showSpikeToast(context,'اختر المحافظة / المدينة');return;}
    setState(()=>_busy=true);
    try{
      final repo=ref.read(authRepositoryProvider);
      if(signup){
        await repo.registerPhone(name:_name.text,phone:phone,password:_password.text,gender:_gender,country:'اليمن',governorate:_governorate,referralCode:_referral.text);
      }else{
        await repo.loginPhone(phone:phone,password:_password.text);
      }
      try{await ref.read(cartRepositoryProvider).mergeGuestCart();}catch(_){}
      ref.invalidate(currentUserProvider);ref.invalidate(cartCountProvider);ref.invalidate(hasSessionProvider);ref.invalidate(addressesProvider);ref.invalidate(shareWinMeProvider);ref.invalidate(shareWinPublicProvider);
      if(mounted){if(context.canPop()){context.pop();}else{context.go(widget.afterLoginRoute);}}
    }catch(e){if(mounted)showSpikeToast(context,e.toString());}
    finally{if(mounted)setState(()=>_busy=false);}
  }

  @override
  Widget build(BuildContext context){
    final muted=Theme.of(context).colorScheme.onSurface.withValues(alpha:.6);
    final fill=Theme.of(context).brightness==Brightness.dark?spikeDarkPanel:const Color(0xFFE7E7E7);
    return Scaffold(body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(SpikeSpacing.page,SpikeSpacing.sm,SpikeSpacing.page,0),child:SizedBox(height:60,child:Stack(alignment:Alignment.center,children:[
        Text(signup?'تسجيل الحساب':'تسجيل الدخول',style:const TextStyle(fontSize:21,fontWeight:FontWeight.w700)),
        Align(alignment:Alignment.centerRight,child:IconButton(onPressed:()=>context.canPop()?context.pop():context.go('/profile'),icon:const Icon(LucideIcons.arrowRight,size:22))),
      ]))),
      Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(SpikeSpacing.page,SpikeSpacing.sm,SpikeSpacing.page,SpikeSpacing.xl),children:[
        if(signup)...[
          _field(_name,'الاسم الكامل',LucideIcons.user,fill),const SizedBox(height:12),
          _select(value:_gender,hint:'اختر الجنس',icon:LucideIcons.users,fill:fill,items:const{'male':'ذكر','female':'أنثى'},onChanged:(v)=>setState(()=>_gender=v??'')),const SizedBox(height:12),
          _readonly('اليمن',LucideIcons.flag,fill),const SizedBox(height:12),
          _select(value:_governorate,hint:'اختر المحافظة / المدينة',icon:LucideIcons.mapPin,fill:fill,items:{for(final g in governorates)g:g},onChanged:(v)=>setState(()=>_governorate=v??'')),const SizedBox(height:12),
          _field(_referral,'كود الدعوة - اختياري',LucideIcons.gift,fill),
          if(_referral.text.isNotEmpty)Padding(padding:const EdgeInsets.fromLTRB(12,5,12,0),child:Text('تمت إضافة كود الدعوة من رابط المشاركة تلقائيًا.',style:TextStyle(fontSize:10,color:muted))),
          const SizedBox(height:12),
        ],
        _field(_phone,'رقم الجوال - مثال: 77xxxxxxx',LucideIcons.phone,fill,keyboard:TextInputType.phone),const SizedBox(height:12),
        _field(_password,'كلمة المرور${signup?' - 8 أحرف على الأقل':''}',LucideIcons.lockKeyhole,fill,obscure:true),
        if(signup)Padding(padding:const EdgeInsets.fromLTRB(12,5,12,0),child:Text('* يجب أن لا تقل كلمة المرور عن 8 أحرف',style:TextStyle(fontSize:10,color:muted)))
        else Align(alignment:Alignment.center,child:TextButton(onPressed:()=>context.push('/password-reset'),child:const Text('هل نسيت كلمة المرور؟',style:TextStyle(fontSize:12)))),
        const SizedBox(height:12),
        SizedBox(height:39,child:FilledButton(style:FilledButton.styleFrom(backgroundColor:spikeRed,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22))),onPressed:_busy?null:_submit,child:_busy?const SizedBox.square(dimension:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):Text(signup?'تسجيل الحساب':'تسجيل الدخول'))),
        TextButton(onPressed:()=>context.go('${signup?'/login':'/signup'}?next=${Uri.encodeComponent(widget.afterLoginRoute)}${_referral.text.isNotEmpty?'&ref=${Uri.encodeComponent(_referral.text)}':''}'),child:Text(signup?'تمتلك حساب؟ قم بتسجيل الدخول من هنا':'لا تملك حساباً؟ قم بإنشاء حساب من هنا',style:const TextStyle(fontSize:12))),
      ])),
    ])));
  }

  Widget _field(TextEditingController c,String hint,IconData icon,Color fill,{bool obscure=false,TextInputType? keyboard})=>SizedBox(height:39,child:TextField(controller:c,obscureText:obscure,keyboardType:keyboard,textCapitalization:hint.contains('كود الدعوة')?TextCapitalization.characters:TextCapitalization.none,decoration:_decoration(hint,icon,fill)));
  Widget _readonly(String value,IconData icon,Color fill)=>SizedBox(height:39,child:TextField(controller:TextEditingController(text:value),readOnly:true,decoration:_decoration(value,icon,fill)));
  Widget _select({required String value,required String hint,required IconData icon,required Color fill,required Map<String,String> items,required ValueChanged<String?> onChanged})=>SizedBox(height:39,child:DropdownButtonFormField<String>(value:value.isEmpty?null:value,isExpanded:true,decoration:_decoration(hint,icon,fill),items:items.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:onChanged));
  InputDecoration _decoration(String hint,IconData icon,Color fill)=>InputDecoration(hintText:hint,filled:true,fillColor:fill,border:OutlineInputBorder(borderSide:BorderSide.none,borderRadius:BorderRadius.circular(22)),enabledBorder:OutlineInputBorder(borderSide:BorderSide.none,borderRadius:BorderRadius.circular(22)),focusedBorder:OutlineInputBorder(borderSide:BorderSide.none,borderRadius:BorderRadius.circular(22)),contentPadding:const EdgeInsets.symmetric(horizontal:16),suffixIcon:Padding(padding:const EdgeInsetsDirectional.only(end:8),child:Icon(icon,size:20)),suffixIconConstraints:const BoxConstraints(minWidth:42));
}
