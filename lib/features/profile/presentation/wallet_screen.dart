import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(walletProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('محفظتي'), leading: IconButton(onPressed: () => context.pop(), icon: const Icon(LucideIcons.arrowRight))),
      body: data.when(
        loading: () => const SpikeLoading(),
        error: (e, _) => SpikeErrorState(message: e.toString(), onRetry: () => ref.invalidate(walletProvider)),
        data: (d) {
          final wallet = Map<String, dynamic>.from(d['wallet'] as Map? ?? const {});
          final tx = (d['transactions'] as List? ?? const []).whereType<Map>().toList();
          final purchases = (d['purchases'] as List? ?? const []).whereType<Map>().toList();
          final summary = Map<String, dynamic>.from(d['summary'] as Map? ?? const {});
          final currency = '${wallet['currency_code'] ?? 'USD'}';
          return RefreshIndicator(
            onRefresh: () async { ref.invalidate(walletProvider); await ref.read(walletProvider.future); },
            child: ListView(padding: const EdgeInsets.all(17), children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? spikeDarkPanel : spikePanel, borderRadius: BorderRadius.circular(22)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('الرصيد المتاح', style: TextStyle(fontSize: 11, color: spikeMuted)),
                  const SizedBox(height: 7),
                  Text('${_number(wallet['balance'])} $currency', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  const Text('رصيد Spike للمبالغ المستردة والمكافآت والرصيد المضاف.', style: TextStyle(fontSize: 10, color: spikeMuted)),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _stat('عدد المشتريات', '${summary['orders_count'] ?? 0}')),
                const SizedBox(width: 10),
                Expanded(child: _stat('إجمالي المشتريات', '${_number(summary['purchases_total'])} USD')),
              ]),
              const SizedBox(height: 24),
              const Text('آخر الحركات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (tx.isEmpty) const _Empty('لا توجد حركات في المحفظة حتى الآن.'),
              for (final x in tx) _row('${x['note'] ?? _type('${x['type'] ?? ''}')}','${x['created_at'] ?? ''}','${x['direction'] == 'credit' ? '+' : '-'}${_number(x['amount'])} $currency'),
              const SizedBox(height: 22),
              const Text('مشترياتي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (purchases.isEmpty) const _Empty('لا توجد مشتريات حتى الآن.'),
              for (final x in purchases.take(8)) _row('طلب #${'${x['id'] ?? ''}'.substring(0, '${x['id'] ?? ''}'.length.clamp(0, 8))}','${x['status'] ?? ''}','${_number(x['total'])} ${x['currency_code'] ?? 'USD'}'),
            ]),
          );
        },
      ),
    );
  }

  static String _number(Object? value) => (num.tryParse('$value') ?? 0).toStringAsFixed(2);
  static String _type(String t) => {'manual_adjustment':'تعديل رصيد','refund':'استرداد','purchase':'شراء','referral_reward':'مكافأة إحالة'}[t] ?? 'حركة رصيد';

  Widget _stat(String label,String value)=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:spikePanel,borderRadius:BorderRadius.circular(17)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:9,color:spikeMuted)),const SizedBox(height:5),Text(value,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w800))]));
  Widget _row(String title,String subtitle,String value)=>Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(13),decoration:BoxDecoration(border:Border.all(color:const Color(0xFFE8E8E8)),borderRadius:BorderRadius.circular(16)),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700)),const SizedBox(height:3),Text(subtitle,style:const TextStyle(fontSize:8,color:spikeMuted))])),Text(value,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800))]));
}

class _Empty extends StatelessWidget { const _Empty(this.text); final String text; @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:18),child:Center(child:Text(text,style:const TextStyle(fontSize:10,color:spikeMuted)))); }
