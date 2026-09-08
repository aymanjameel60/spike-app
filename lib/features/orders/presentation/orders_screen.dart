import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/providers.dart';
import '../../../core/api_config.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});
  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  bool previous = false;

  bool _done(String status) => const {'delivered', 'returned', 'rejected'}.contains(status);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ordersProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _head(context, 'طلباتي'),
          Padding(
            padding: const EdgeInsets.fromLTRB(SpikeSpacing.page, 0, SpikeSpacing.page, 18),
            child: Row(children: [
              _tab('الحالية', !previous, () => setState(() => previous = false), dark),
              const SizedBox(width: 9),
              _tab('السابقة', previous, () => setState(() => previous = true), dark),
            ]),
          ),
          Expanded(
            child: state.when(
              loading: () => const SpikeLoading(),
              error: (e, _) => SpikeErrorState(message: e.toString(), onRetry: () => ref.invalidate(ordersProvider)),
              data: (orders) {
                final list = orders.where((o) => previous ? _done(o.status) : !_done(o.status)).toList();
                if (list.isEmpty) return SpikeEmptyState(message: previous ? 'لا توجد طلبات سابقة حتى الآن' : 'طلباتك الجديدة ستظهر هنا');
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(ordersProvider);
                    await ref.read(ordersProvider.future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(SpikeSpacing.page, 0, SpikeSpacing.page, SpikeSpacing.xl),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 13),
                    itemBuilder: (context, i) {
                      final o = list[i];
                      final statusColor = _statusColor(o.status);
                      return InkWell(
                        onTap: () => context.push('/order/${o.id}'),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: dark ? spikeDarkPanel : const Color(0xFFE9E9E9),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(_status(o.status), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: statusColor)),
                                  if (o.displayDate.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(o.displayDate, style: const TextStyle(fontSize: 9, color: spikeMuted))),
                                ]),
                              ),
                              Directionality(textDirection: TextDirection.ltr, child: Text('#${_short(o.id)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            ]),
                            const Padding(padding: EdgeInsets.symmetric(vertical: 11), child: Divider(height: 1)),
                            Row(children: [
                              Expanded(child: Text(o.paymentMethod == 'cod' ? 'الدفع عند الاستلام' : 'حوالة مالية', style: const TextStyle(fontSize: 10, color: spikeMuted))),
                              Text('${o.total.toStringAsFixed(2)} ${o.currencyCode}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                              const SizedBox(width: 8),
                              const Icon(LucideIcons.chevronLeft, size: 18, color: spikeMuted),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap, bool dark) => SizedBox(
        width: 88,
        height: 39,
        child: FilledButton(
          style: FilledButton.styleFrom(
            elevation: 0,
            padding: EdgeInsets.zero,
            backgroundColor: active ? (dark ? Colors.white : Colors.black) : (dark ? spikeDarkPanel : const Color(0xFFE7E7E7)),
            foregroundColor: active ? (dark ? Colors.black : Colors.white) : Theme.of(context).colorScheme.onSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          ),
          onPressed: onTap,
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      );
}

class OrderDetailsScreen extends ConsumerStatefulWidget {
  const OrderDetailsScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  bool receiptBusy = false;
  String? returnBusyId;
  String? reviewBusyId;
  String? storeReviewBusyId;

  String _asset(String raw) => ApiConfig.resolveMedia(raw);

  Future<void> _receipt() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1800);
    if (x == null) return;
    setState(() => receiptBusy = true);
    try {
      await ref.read(commerceRepositoryProvider).uploadReceipt(widget.id, x.path);
      ref.invalidate(orderDetailsProvider(widget.id));
      if (mounted) showSpikeToast(context, 'تم رفع سند الحوالة وإرساله للمراجعة');
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    } finally {
      if (mounted) setState(() => receiptBusy = false);
    }
  }

  Future<void> _reviewProduct(Map<String, dynamic> item) async {
    final comment = TextEditingController();
    int rating = 5;
    final submit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(17, 18, 17, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
          child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('تقييم المنتج', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: rating,
              items: [5, 4, 3, 2, 1].map((v) => DropdownMenuItem(value: v, child: Text('${'★' * v}${'☆' * (5 - v)}'))).toList(),
              onChanged: (v) => setSheetState(() => rating = v ?? 5),
            ),
            const SizedBox(height: 10),
            TextField(controller: comment, maxLines: 3, decoration: const InputDecoration(hintText: 'تعليقك - اختياري')),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.pop(sheetContext, true), style: FilledButton.styleFrom(backgroundColor: spikeRed), child: const Text('إرسال تقييم المنتج')),
          ])),
        ),
      ),
    );
    if (submit != true) { comment.dispose(); return; }
    final id = '${item['id'] ?? ''}';
    setState(() => reviewBusyId = id);
    try {
      await ref.read(engagementRepositoryProvider).reviewProduct(orderItemId: id, rating: rating, comment: comment.text.trim().isEmpty ? null : comment.text.trim());
      ref.invalidate(orderDetailsProvider(widget.id));
      if (mounted) showSpikeToast(context, 'تم إرسال تقييم المنتج');
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    } finally {
      comment.dispose();
      if (mounted) setState(() => reviewBusyId = null);
    }
  }

  Future<void> _reviewStore(Map<String, dynamic> store) async {
    final comment = TextEditingController();
    int rating = 5;
    final submit = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (sheetContext) => StatefulBuilder(builder: (_, setSheetState) => Padding(
      padding: EdgeInsets.fromLTRB(17, 18, 17, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('تقييم متجر ${store['store_name'] ?? ''}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(value: rating, items: [5, 4, 3, 2, 1].map((v) => DropdownMenuItem(value: v, child: Text('${'★' * v}${'☆' * (5 - v)}'))).toList(), onChanged: (v) => setSheetState(() => rating = v ?? 5)),
        const SizedBox(height: 10),
        TextField(controller: comment, maxLines: 3, decoration: const InputDecoration(hintText: 'تعليقك - اختياري')),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => Navigator.pop(sheetContext, true), style: FilledButton.styleFrom(backgroundColor: spikeRed), child: const Text('إرسال تقييم المتجر')),
      ])),
    )));
    if (submit != true) { comment.dispose(); return; }
    final id = '${store['suborder_id'] ?? store['id'] ?? ''}';
    setState(() => storeReviewBusyId = id);
    try {
      await ref.read(engagementRepositoryProvider).reviewStore(suborderId: id, rating: rating, comment: comment.text.trim().isEmpty ? null : comment.text.trim());
      ref.invalidate(orderDetailsProvider(widget.id));
      if (mounted) showSpikeToast(context, 'تم إرسال تقييم المتجر');
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    } finally {
      comment.dispose();
      if (mounted) setState(() => storeReviewBusyId = null);
    }
  }

  Future<void> _requestReturn(Map<String, dynamic> item) async {
    final maxQty = int.tryParse('${item['quantity'] ?? 1}') ?? 1;
    final reason = TextEditingController();
    int qty = 1;
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(SpikeRadius.sheet))),
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(SpikeSpacing.page, SpikeSpacing.md, SpikeSpacing.page, MediaQuery.of(context).viewInsets.bottom + SpikeSpacing.xl),
        child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [const Expanded(child: Text('طلب إرجاع', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))), IconButton(onPressed: () => Navigator.pop(sheetContext, false), icon: const Icon(LucideIcons.x))]),
          Text('${item['product_name'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: SpikeSpacing.lg),
          const Text('الكمية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: SpikeSpacing.sm),
          Row(children: [
            IconButton(onPressed: qty > 1 ? () => setSheetState(() => qty--) : null, icon: const Icon(Icons.remove_circle_outline)),
            Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            IconButton(onPressed: qty < maxQty ? () => setSheetState(() => qty++) : null, icon: const Icon(Icons.add_circle_outline)),
            Text('من $maxQty', style: const TextStyle(fontSize: 10, color: spikeMuted)),
          ]),
          const SizedBox(height: SpikeSpacing.sm),
          TextField(controller: reason, maxLines: 4, decoration: const InputDecoration(labelText: 'سبب الإرجاع', hintText: 'اكتب سبب الإرجاع بوضوح')),
          const SizedBox(height: SpikeSpacing.md),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: spikeRed), onPressed: () {
            if (reason.text.trim().length < 3) {
              showSpikeToast(context, 'اكتب سبب الإرجاع');
              return;
            }
            Navigator.pop(sheetContext, true);
          }, child: const Text('إرسال طلب الإرجاع')),
        ])),
      )),
    );
    if (submitted != true) {
      reason.dispose();
      return;
    }
    final text = reason.text.trim();
    reason.dispose();
    final id = '${item['id'] ?? ''}';
    setState(() => returnBusyId = id);
    try {
      await ref.read(commerceRepositoryProvider).requestReturn(orderItemId: id, quantity: qty, reason: text);
      ref.invalidate(orderDetailsProvider(widget.id));
      ref.invalidate(returnsHistoryProvider);
      if (mounted) showSpikeToast(context, 'تم إرسال طلب الإرجاع للإدارة');
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    } finally {
      if (mounted) setState(() => returnBusyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(orderDetailsProvider(widget.id));
    final timeline = ref.watch(orderTimelineProvider(widget.id));
    return Scaffold(body: SafeArea(child: Column(children: [
      _head(context, 'تفاصيل الطلب'),
      Expanded(child: details.when(
        loading: () => const SpikeLoading(),
        error: (e, _) => SpikeErrorState(message: e.toString(), onRetry: () => ref.invalidate(orderDetailsProvider(widget.id))),
        data: (d) {
          final order = Map<String, dynamic>.from(d['order'] as Map? ?? const {});
          final subs = (d['suborders'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          final items = (d['items'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          final transfer = order['payment_method'] == 'transfer';
          final needsReceipt = transfer && order['status'] == 'pending_admin_review' && (order['receipt_url'] == null || '${order['receipt_url']}'.isEmpty);
          final orderDate = _dateTime(order['created_at']);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(orderDetailsProvider(widget.id));
              ref.invalidate(orderTimelineProvider(widget.id));
              await ref.read(orderDetailsProvider(widget.id).future);
            },
            child: ListView(padding: SpikeSpacing.pageList, children: [
              _box(context, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('طلب #${_short(widget.id)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    const SizedBox(height: SpikeSpacing.sm),
                    Align(alignment: Alignment.centerRight, child: _pill(_status('${order['status'] ?? ''}'), _statusColor('${order['status'] ?? ''}'))),
                  ])),
                  Text('${order['total'] ?? 0} ${order['currency_code'] ?? ''}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: SpikeSpacing.md),
                const Divider(),
                const SizedBox(height: SpikeSpacing.sm),
                if (orderDate.isNotEmpty) _info(LucideIcons.calendarDays, 'تاريخ الطلب', orderDate),
                _info(LucideIcons.walletCards, 'الدفع', '${transfer ? 'حوالة مالية' : 'عند الاستلام'} • ${_payment('${order['payment_status'] ?? ''}')}'),
                if (order['address_line'] != null) _info(LucideIcons.mapPin, 'التوصيل', '${order['address_line']}'),
              ])),
              if (transfer)
                _box(context, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Row(children: [Icon(LucideIcons.receipt, size: 18), SizedBox(width: SpikeSpacing.sm), Text('سند الحوالة', style: TextStyle(fontWeight: FontWeight.w900))]),
                  const SizedBox(height: SpikeSpacing.sm),
                  Text(needsReceipt ? 'ارفع صورة سند الحوالة ليتمكن الأدمن من مراجعة الطلب.' : 'حالة السند: ${_payment('${order['payment_status'] ?? ''}')}', style: const TextStyle(fontSize: 11, height: 1.5)),
                  if (needsReceipt) ...[
                    const SizedBox(height: SpikeSpacing.md),
                    FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: spikeRed), onPressed: receiptBusy ? null : _receipt, icon: const Icon(LucideIcons.upload, size: 17), label: Text(receiptBusy ? 'جاري الرفع...' : 'رفع سند الحوالة')),
                  ],
                ])),
              const SizedBox(height: SpikeSpacing.sm),
              _sectionTitle(LucideIcons.route, 'تتبع الطلب'),
              timeline.when(
                loading: () => const Padding(padding: EdgeInsets.all(SpikeSpacing.md), child: SpikeLoading()),
                error: (e, _) => Text(e.toString()),
                data: (rows) => rows.isEmpty
                    ? const _MiniEmpty('لا توجد تحديثات بعد')
                    : Column(children: List.generate(rows.length, (i) {
                        final x = rows[i], last = i == rows.length - 1;
                        final status = '${x['status'] ?? ''}';
                        final date = _dateTime(x['created_at']);
                        final store = '${x['store_name'] ?? ''}'.trim();
                        final meta = [if (store.isNotEmpty) store, if (date.isNotEmpty) date].join(' • ');
                        final color = _statusColor(status);
                        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(width: 28, child: Column(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), if (!last) Container(width: 2, height: 45, color: color.withValues(alpha: .18))])),
                          Expanded(child: Padding(padding: const EdgeInsets.only(bottom: SpikeSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_status(status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)), if (meta.isNotEmpty) Text(meta, style: const TextStyle(fontSize: 9, color: spikeMuted))]))),
                        ]);
                      })),
              ),
              if (subs.isNotEmpty) ...[
                const SizedBox(height: SpikeSpacing.sm),
                _sectionTitle(LucideIcons.store, 'طلبات المتاجر'),
                for (final s in subs)
                  _box(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text('${s['store_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900))), _pill(_status('${s['status'] ?? ''}'), _statusColor('${s['status'] ?? ''}'))]),
                    if (s['delivery_office_name'] != null) Padding(padding: const EdgeInsets.only(top: SpikeSpacing.sm), child: _info(LucideIcons.truck, 'مكتب التوصيل', '${s['delivery_office_name']}')),
                    if (s['shipping_total'] != null) _info(LucideIcons.banknote, 'تكلفة التوصيل', '${s['shipping_total']} ${s['currency_code'] ?? ''}'),
                    if (s['can_review_store'] == true) Padding(padding: const EdgeInsets.only(top: SpikeSpacing.md), child: OutlinedButton.icon(onPressed: storeReviewBusyId == '${s['suborder_id'] ?? s['id'] ?? ''}' ? null : () => _reviewStore(s), icon: const Icon(LucideIcons.star, size: 16), label: Text(storeReviewBusyId == '${s['suborder_id'] ?? s['id'] ?? ''}' ? 'جاري الإرسال...' : 'إرسال تقييم المتجر'))),
                  ])),
              ],
              const SizedBox(height: SpikeSpacing.sm),
              _sectionTitle(LucideIcons.package, 'المنتجات'),
              for (final item in items)
                _box(context, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    InkWell(
                      onTap: '${item['product_id'] ?? ''}'.isEmpty ? null : () => context.push('/product/${item['product_id']}'),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 78,
                        height: 78,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(18)),
                        child: '${item['image_url'] ?? ''}'.trim().isEmpty ? const Icon(LucideIcons.package, size: 18) : CachedNetworkImage(imageUrl: _asset('${item['image_url']}'), fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(LucideIcons.package, size: 18)),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(child: InkWell(onTap: '${item['product_id'] ?? ''}'.isEmpty ? null : () => context.push('/product/${item['product_id']}'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${item['product_name'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('${item['store_name'] ?? ''}${'${item['variant_title'] ?? ''}'.isEmpty ? '' : ' • ${item['variant_title']}'}', style: const TextStyle(fontSize: 9, color: spikeMuted)),
                      const SizedBox(height: 3),
                      Text('×${item['quantity'] ?? 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    ]))),
                  ]),
                  if (item['can_review_product'] == true) Padding(padding: const EdgeInsets.only(top: SpikeSpacing.md), child: OutlinedButton.icon(onPressed: reviewBusyId == '${item['id']}' ? null : () => _reviewProduct(item), icon: const Icon(LucideIcons.star, size: 16), label: Text(reviewBusyId == '${item['id']}' ? 'جاري الإرسال...' : 'إرسال تقييم المنتج'))),
                  if (item['can_return'] == true) Padding(padding: const EdgeInsets.only(top: SpikeSpacing.md), child: OutlinedButton.icon(onPressed: returnBusyId == '${item['id']}' ? null : () => _requestReturn(item), icon: const Icon(LucideIcons.rotateCcw, size: 16), label: Text(returnBusyId == '${item['id']}' ? 'جاري الإرسال...' : 'طلب إرجاع'))),
                  if (item['has_return_request'] == true) const Padding(padding: EdgeInsets.only(top: SpikeSpacing.sm), child: Row(children: [Icon(LucideIcons.clock3, size: 15, color: Colors.orange), SizedBox(width: SpikeSpacing.sm), Text('تم تسجيل طلب إرجاع لهذا المنتج', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange))])),
                ])),
            ]),
          );
        },
      )),
    ])));
  }
}

Widget _head(BuildContext context, String title) => Padding(
      padding: const EdgeInsets.fromLTRB(SpikeSpacing.page, SpikeSpacing.sm, SpikeSpacing.page, 0),
      child: SizedBox(
        height: 60,
        child: Stack(alignment: Alignment.center, children: [
          Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
          Align(alignment: Alignment.centerRight, child: SizedBox(width: 50, height: 40, child: IconButton(onPressed: () => context.canPop() ? context.pop() : context.go('/profile'), icon: const Icon(LucideIcons.arrowRight, size: 22)))),
        ]),
      ),
    );
Widget _box(BuildContext context, Widget child) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? spikeDarkPanel : const Color(0xFFE9E9E9), borderRadius: BorderRadius.circular(24)), child: child);
Widget _sectionTitle(IconData icon, String title) => Padding(padding: const EdgeInsets.only(bottom: SpikeSpacing.sm), child: Row(children: [Icon(icon, size: 18), const SizedBox(width: SpikeSpacing.sm), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))]));
Widget _info(IconData icon, String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: SpikeSpacing.xs), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 15, color: spikeMuted), const SizedBox(width: SpikeSpacing.sm), Text('$label: ', style: const TextStyle(fontSize: 10, color: spikeMuted)), Expanded(child: Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)))]));
Widget _pill(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: SpikeSpacing.sm, vertical: SpikeSpacing.xs), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)), child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color)));
String _short(String s) => s.length > 8 ? s.substring(0, 8) : s;
String _dateTime(dynamic raw) {
  final value = '${raw ?? ''}'.trim();
  if (value.isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final d = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}/${two(d.month)}/${two(d.day)} • ${two(d.hour)}:${two(d.minute)}';
}
Color _statusColor(String s) {
  if (s == 'delivered' || s == 'approved' || s == 'accepted') return Colors.green;
  if (s == 'rejected' || s == 'returned') return spikeRed;
  if (s == 'assigned' || s == 'picked_up' || s == 'with_courier' || s == 'ready_for_delivery') return Colors.blue;
  return Colors.orange;
}
String _status(String s) => const {
      'pending_admin_review': 'قيد مراجعة الإدارة',
      'accepted': 'مقبول',
      'approved': 'تمت الموافقة',
      'processing': 'قيد التجهيز',
      'ready_for_delivery': 'جاهز للتوصيل',
      'assigned': 'تم تعيين مكتب التوصيل',
      'picked_up': 'تم استلامه من المتجر',
      'with_courier': 'مع المندوب',
      'delivered': 'تم التوصيل',
      'rejected': 'مرفوض',
      'returned': 'مرتجع',
    }[s] ?? s;
String _payment(String s) => const {
      'pending_review': 'قيد مراجعة السند',
      'approved': 'تم اعتماد الدفع',
      'pending_collection': 'يُحصّل عند الاستلام',
      'paid': 'مدفوع',
      'rejected': 'مرفوض',
    }[s] ?? s;

class _MiniEmpty extends StatelessWidget {
  const _MiniEmpty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: SpikeSpacing.md), child: Text(text, style: const TextStyle(fontSize: 11, color: spikeMuted)));
}
