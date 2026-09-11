import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/providers.dart';
import '../../../core/api_config.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';

class ShareWinScreen extends ConsumerWidget {
  const ShareWinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data=ref.watch(shareWinMeProvider);
    return Scaffold(
      appBar: AppBar(
        centerTitle:true,
        title:const Text('شارك واربح',style:TextStyle(fontWeight:FontWeight.w700)),
        leading:IconButton(onPressed:()=>context.canPop()?context.pop():context.go('/profile'),icon:const Icon(LucideIcons.arrowRight)),
      ),
      body:SafeArea(
        child:data.when(
          loading:()=>const SpikeLoading(),
          error:(e,_)=>SpikeErrorState(message:e.toString(),onRetry:()=>ref.invalidate(shareWinMeProvider)),
          data:(d){
            if(d['enabled']!=true)return const Center(child:Text('ميزة شارك واربح غير مفعلة حالياً'));
            final code='${d['code']??''}',headline='${d['headline']??'شارك واربح'}',description='${d['description']??''}';
            final rewardAmount=double.tryParse('${d['reward_amount']??0}')??0,rewardCurrency='${d['reward_currency']??''}',rewardType='${d['reward_type']??'wallet'}';
            final referrals=(d['referrals'] is List?(d['referrals'] as List):const[]).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
            final link=ApiConfig.referralLink(code);
            final rewardLabel=rewardType=='coupon'?'كوبون بقيمة ${_num(rewardAmount)} $rewardCurrency':'${_num(rewardAmount)} $rewardCurrency في محفظة Spike';
            return RefreshIndicator(
              onRefresh:()async=>ref.invalidate(shareWinMeProvider),
              child:ListView(
                padding:const EdgeInsets.fromLTRB(18,12,18,28),
                children:[
                  Text(headline,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),
                  const SizedBox(height:8),
                  Text(description,style:TextStyle(color:Theme.of(context).colorScheme.onSurface.withValues(alpha:.65),height:1.5)),
                  const SizedBox(height:8),
                  const Text('المكافأة لا تُصرف عند التسجيل. تُضاف بعد توصيل أول طلب للعميل المدعو بالكامل، ولمرة واحدة فقط لكل صديق.',style:TextStyle(fontSize:12,height:1.5)),
                  const SizedBox(height:16),
                  _card(context,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    const Text('المكافأة الحالية',style:TextStyle(fontSize:12)),
                    const SizedBox(height:4),
                    Text(rewardLabel,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800)),
                  ])),
                  const SizedBox(height:12),
                  Row(children:[
                    Expanded(child:_stat(context,'الإحالات','${d['referrals_count']??0}')),
                    const SizedBox(width:8),
                    Expanded(child:_stat(context,'بانتظار الطلب','${d['pending_count']??0}')),
                    const SizedBox(width:8),
                    Expanded(child:_stat(context,'مكتسبة','${d['earned_count']??0}')),
                  ]),
                  const SizedBox(height:12),
                  _card(context,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                    const Text('كود دعوتك',style:TextStyle(fontSize:12)),
                    const SizedBox(height:5),
                    Text(code,textAlign:TextAlign.center,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,letterSpacing:1.2)),
                    const SizedBox(height:12),
                    Row(children:[
                      Expanded(child:FilledButton.icon(onPressed:()=>Share.share('انضم إلى Spike عبر رابط دعوتي. المكافأة تُحتسب بعد توصيل أول طلب لك.\n$link'),icon:const Icon(LucideIcons.share2,size:18),label:const Text('مشاركة الرابط'),style:FilledButton.styleFrom(backgroundColor:Colors.black))),
                      const SizedBox(width:8),
                      Expanded(child:OutlinedButton.icon(onPressed:()async{await Clipboard.setData(ClipboardData(text:link));if(context.mounted)showSpikeToast(context,'تم نسخ رابط الدعوة');},icon:const Icon(LucideIcons.copy,size:18),label:const Text('نسخ الرابط'))),
                    ]),
                  ])),
                  const SizedBox(height:18),
                  const Text('حالة الدعوات',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800)),
                  const SizedBox(height:8),
                  if(referrals.isEmpty)_card(context,child:const Center(child:Padding(padding:EdgeInsets.all(10),child:Text('لم تسجل أي دعوات بعد.'))))
                  else ...referrals.map((x)=>Padding(padding:const EdgeInsets.only(bottom:8),child:_referral(context,x))),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static Widget _card(BuildContext context,{required Widget child})=>Container(
    padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(color:Theme.of(context).brightness==Brightness.dark?spikeDarkPanel:spikePanel,borderRadius:BorderRadius.circular(16)),
    child:child,
  );

  static Widget _stat(BuildContext context,String label,String value)=>_card(context,child:Column(children:[Text(label,textAlign:TextAlign.center,style:const TextStyle(fontSize:11)),const SizedBox(height:4),Text(value,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800))]));

  static Widget _referral(BuildContext context,Map<String,dynamic> x){
    final earned=x['status']=='earned',coupon='${x['reward_coupon_code']??''}';
    return _card(context,child:Row(children:[
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(earned?'تمت المكافأة':'بانتظار أول طلب',style:const TextStyle(fontWeight:FontWeight.w800)),
        const SizedBox(height:4),
        Text(earned?'تم توصيل أول طلب بنجاح':'لم يكتمل أول طلب بعد',style:const TextStyle(fontSize:11)),
        if(earned&&coupon.isNotEmpty)...[
          const SizedBox(height:8),
          OutlinedButton.icon(onPressed:()async{await Clipboard.setData(ClipboardData(text:coupon));if(context.mounted)showSpikeToast(context,'تم نسخ كود المكافأة');},icon:const Icon(LucideIcons.copy,size:14),label:Text(coupon)),
        ],
      ])),
      Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),decoration:BoxDecoration(color:earned?const Color(0xFFE8F5E9):const Color(0xFFFFF4D6),borderRadius:BorderRadius.circular(20)),child:Text(earned?'مكتسبة':'معلقة',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:earned?const Color(0xFF137333):const Color(0xFF8A5B00))))
    ]));
  }

  static String _num(double n)=>n==n.roundToDouble()?n.toInt().toString():n.toStringAsFixed(2);
}
