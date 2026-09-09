import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import '../../cart/data/cart_repository.dart';
import '../data/commerce_repository.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  CartSnapshot? cart;
  List<AddressModel> addresses = [];
  List<PaymentMethodModel> methods = [];
  List<CurrencyModel> currencies = [];
  AddressModel? address;
  PaymentMethodModel? payment;
  CurrencyModel? currency;
  DeliveryQuote? quote;
  bool loading = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final commerce = ref.read(commerceRepositoryProvider);
      final preferred = ref.read(appSettingsProvider).currency;
      final result = await Future.wait([
        ref.read(cartRepositoryProvider).load(),
        commerce.addresses(),
        commerce.paymentMethods(),
        commerce.currencies(),
      ]);
      cart = result[0] as CartSnapshot;
      addresses = result[1] as List<AddressModel>;
      methods = result[2] as List<PaymentMethodModel>;
      currencies = result[3] as List<CurrencyModel>;
      address = addresses.where((a) => a.isActive).cast<AddressModel?>().firstOrNull ?? (addresses.isNotEmpty ? addresses.first : null);
      payment = null;
      currency = currencies.where((c) => c.code == preferred).cast<CurrencyModel?>().firstOrNull ??
          currencies.where((c) => c.code == (cart?.currencyCode ?? 'USD')).cast<CurrencyModel?>().firstOrNull ??
          (currencies.isNotEmpty ? currencies.first : null);
      if (currency != null) {
        cart = await ref.read(cartRepositoryProvider).updateMeta(currencyCode: currency!.code);
      }
      if (address != null && cart!.items.isNotEmpty) {
        quote = await commerce.quote(addressId: address!.id, variantIds: cart!.items.map((e) => e.variantId).toList());
      }
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _chooseAddress() async {
    await context.push('/addresses');
    final list = await ref.read(commerceRepositoryProvider).addresses();
    final selected = list.where((a) => a.isActive).cast<AddressModel?>().firstOrNull;
    if (selected == null) {
      if (mounted) setState(() {
        addresses = list;
        address = null;
        payment = null;
        quote = null;
      });
      return;
    }
    setState(() {
      addresses = list;
      address = selected;
      payment = null;
    });
    quote = await ref.read(commerceRepositoryProvider).quote(addressId: selected.id, variantIds: cart!.items.map((e) => e.variantId).toList());
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (busy || cart == null || address == null || payment == null || currency == null) return;
    setState(() => busy = true);
    try {
      final order = await ref.read(commerceRepositoryProvider).createOrder(
            cart: cart!,
            addressId: address!.id,
            paymentMethod: payment!.method,
            currencyCode: currency!.code,
          );
      ref.invalidate(cartCountProvider);
      ref.invalidate(ordersProvider);
      if (mounted) {
        showSpikeToast(context, 'تم إنشاء الطلب بنجاح');
        context.go('/order/${order.id}');
      }
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: SpikeLoading());
    if (cart == null) return Scaffold(body: SpikeErrorState(onRetry: _load));

    if (cart!.items.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Column(children: [
            const _CheckoutHead(title: 'تأكيد الطلب والدفع'),
            const Expanded(child: SpikeEmptyState(message: 'السلة فارغة، أضف منتجات قبل إتمام الطلب')),
            Padding(
              padding: const EdgeInsets.all(17),
              child: SizedBox(width: double.infinity, height: 43, child: FilledButton(onPressed: () => context.go('/'), child: const Text('العودة للتسوق'))),
            ),
          ]),
        ),
      );
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    final panel = dark ? spikeDarkPanel : spikePanel;
    final card = dark ? const Color(0xFF1D1D1D) : Colors.white;
    final hasAddress = address != null;
    final ready = hasAddress && payment != null && currency != null && !busy;
    final delivery = quote?.shippingYerOld ?? 0;
    final grand = cart!.subtotal + delivery;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const _CheckoutHead(title: 'تأكيد الطلب والدفع'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(17, 4, 17, 24),
              children: [
                InkWell(
                  onTap: _chooseAddress,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: card, border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      const Icon(LucideIcons.mapPin, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address == null ? 'اختر عنوان التوصيل' : '${address!.label} - ${address!.cityName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Text('تغيير', style: TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(22)),
                  child: Row(children: [
                    const Icon(LucideIcons.truck, size: 18),
                    const SizedBox(width: 9),
                    const Expanded(child: Text('مكتب التوصيل محدد لكل منتج من التاجر', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                    if (quote != null) Text('${delivery.round()} ر.ي قديم', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Text('طريقة الدفع', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 9),
                Opacity(
                  opacity: hasAddress ? 1 : .42,
                  child: IgnorePointer(
                    ignoring: !hasAddress,
                    child: Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: [
                        for (final method in methods)
                          InkWell(
                            onTap: hasAddress ? () => setState(() => payment = method) : null,
                            borderRadius: BorderRadius.circular(17),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 48),
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(17),
                                border: Border.all(color: payment?.method == method.method ? Theme.of(context).colorScheme.onSurface : Theme.of(context).dividerColor),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(payment?.method == method.method ? Icons.radio_button_checked : Icons.radio_button_off, size: 18),
                                const SizedBox(width: 7),
                                Text(method.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!hasAddress)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(5, 8, 5, 0),
                    child: Text('أضف أو اختر عنوان التوصيل أولاً لتفعيل طرق الدفع.', style: TextStyle(fontSize: 11, color: spikeMuted, fontWeight: FontWeight.w700)),
                  ),
                if (payment != null && payment!.instructions.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18), border: Border.all(color: Theme.of(context).dividerColor)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('بيانات التحويل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(payment!.instructions, style: const TextStyle(fontSize: 10, height: 1.55)),
                      const SizedBox(height: 10),
                      const Text('بعد تأكيد الطلب سترفع سند الحوالة من قسم طلباتي.', style: TextStyle(fontSize: 9, color: spikeMuted, height: 1.5)),
                    ]),
                  ),
                ],
                const SizedBox(height: 13),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(22)),
                  child: Column(children: [
                    _InvoiceLine(label: 'المنتجات بعد الخصومات', value: _money(cart!.subtotal, cart!.currencyCode)),
                    _InvoiceLine(label: 'رسوم مكتب التوصيل', value: quote == null ? 'تحسب عند التأكيد' : '${delivery.round()} ر.ي قديم'),
                    Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('الإجمالي مع التوصيل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(_money(grand, cart!.currencyCode), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 43,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: spikeRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
                    onPressed: ready ? _submit : null,
                    child: busy
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('تأكيد الطلب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  String _money(double amount, String code) {
    final c = code.toUpperCase();
    if (c == 'USD') return '\$${amount.toStringAsFixed(2)}';
    if (c == 'SAR') return '${amount.toStringAsFixed(2)} ر.س';
    if (c.startsWith('YER')) return '${amount.round()} ر.ي';
    if (c == 'TRY') return '${amount.toStringAsFixed(2)} ₺';
    return '${amount.toStringAsFixed(2)} $c';
  }
}

class _CheckoutHead extends StatelessWidget {
  const _CheckoutHead({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17),
          child: Stack(alignment: Alignment.center, children: [
            Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 50,
                height: 40,
                child: Material(
                  color: Theme.of(context).brightness == Brightness.dark ? spikeDarkPanel : const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => context.canPop() ? context.pop() : context.go('/cart'),
                    child: const Icon(LucideIcons.arrowRight, size: 23),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
}

class _InvoiceLine extends StatelessWidget {
  const _InvoiceLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 36),
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
