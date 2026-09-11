import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/providers.dart';
import '../../../core/api_config.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user=ref.watch(currentUserProvider),shareWin=ref.watch(shareWinPublicProvider).valueOrNull;
    return SafeArea(child:user.when(
      loading:()=>const SpikeLoading(),
      error:(e,_)=>SpikeErrorState(message:e.toString(),onRetry:()=>ref.invalidate(currentUserProvider)),
      data:(u){
        final current=u??<String,dynamic>{};
        final raw='${current['avatar_url']??current['avatarUrl']??''}',avatar=ApiConfig.resolveMedia(raw),name='${current['name']??''}',phone='${current['phone']??''}',rawEmail='${current['email']??''}',email=rawEmail.endsWith('@customer.spike.local')?'':rawEmail;
        return ListView(padding:EdgeInsets.zero,children:[
          const _SimpleTitle('الملف الشخصي'),
          Padding(padding:const EdgeInsets.fromLTRB(20,10,20,24),child:Row(children:[
            SizedBox(width:70,height:70,child:ClipOval(child:ColoredBox(color:spikeRed,child:avatar.isEmpty?const SizedBox.expand():CachedNetworkImage(imageUrl:avatar,fit:BoxFit.cover,width:70,height:70)))),
            const SizedBox(width:14),
            Expanded(child:Text(name.isEmpty?'مرحباً بك في Spike\nسجّل الدخول لمتابعة طلباتك وبياناتك':'مرحباً $name${phone.isNotEmpty?'\n$phone':''}${email.isNotEmpty?'\n$email':''}',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700,height:1.7))),
          ])),
          Padding(padding:const EdgeInsets.symmetric(horizontal:17),child:Column(children:[
            _row(context,LucideIcons.userRound,'البيانات الشخصية',()=>context.push('/personal-data')),const SizedBox(height:16),
            _row(context,LucideIcons.store,'المتاجر',()=>context.push('/stores')),const SizedBox(height:16),
            if(shareWin?['enabled']==true)...[_row(context,LucideIcons.gift,'${shareWin?['headline']??'شارك واربح'}',()=>u==null?context.push('/login?next=${Uri.encodeComponent('/share-win')}'):context.push('/share-win'),featured:true),const SizedBox(height:16)],
            _row(context,LucideIcons.heart,'المفضلة',()=>context.push('/favorites')),const SizedBox(height:16),
            _row(context,LucideIcons.packageCheck,'طلباتي',()=>context.push('/orders')),const SizedBox(height:16),
            _row(context,LucideIcons.messagesSquare,'خدمة العملاء',()=>context.push('/support')),const SizedBox(height:16),
            _row(context,LucideIcons.shieldCheck,'سياسة الخصوصية',()=>context.push('/privacy')),const SizedBox(height:16),
            _row(context,LucideIcons.settings2,'الإعدادات المتقدمة',()=>context.push('/settings')),const SizedBox(height:16),
            _row(context,u==null?LucideIcons.logIn:LucideIcons.logOut,u==null?'تسجيل الدخول':'تسجيل الخروج',()async{
              if(u==null){context.push('/login');return;}
              await ref.read(authRepositoryProvider).logout();
              ref.invalidate(currentUserProvider);ref.invalidate(hasSessionProvider);ref.invalidate(shareWinMeProvider);
              if(context.mounted)context.go('/profile');
            },danger:u!=null),
            const SizedBox(height:24),
          ])),
        ]);
      },
    ));
  }

  Widget _row(BuildContext context,IconData icon,String label,VoidCallback onTap,{bool danger=false,bool featured=false}){
    final dark=Theme.of(context).brightness==Brightness.dark;
    return Material(color:featured?(dark?const Color(0xFF311619):const Color(0xFFFFF1F2)):(dark?spikeDarkPanel:spikePanel),borderRadius:BorderRadius.circular(16),child:InkWell(borderRadius:BorderRadius.circular(16),onTap:onTap,child:SizedBox(height:43,child:Padding(padding:const EdgeInsets.symmetric(horizontal:22),child:Row(children:[
      Icon(icon,size:21,color:danger?spikeRed:Theme.of(context).colorScheme.onSurface),const SizedBox(width:12),Expanded(child:Text(label,style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:danger?spikeRed:null))),
      if(featured)Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),decoration:BoxDecoration(color:spikeRed,borderRadius:BorderRadius.circular(20)),child:const Text('جديد',style:TextStyle(fontSize:9,fontWeight:FontWeight.w800,color:Colors.white))),
    ])))));
  }
}

class _SimpleTitle extends StatelessWidget {
  const _SimpleTitle(this.title);final String title;
  @override Widget build(BuildContext context)=>SizedBox(height:60,child:Center(child:Text(title,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w700))));
}
