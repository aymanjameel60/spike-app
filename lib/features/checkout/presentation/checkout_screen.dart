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
  List<PaymentAccountModel> paymentAccounts = [];
  List<CheckoutBannerModel> checkoutBanners = [];
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

  Future<void> _refreshQuote() async {
    if (address == null || cart == null || cart!.items.isEmpty) {
      quote = null;
      return;
    }
    quote = await ref.read(commerceRepositoryProvider).quote(addressId: address!.id, cart: cart!);
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
        commerce.paymentAccounts(),
        commerce.checkoutBanners(),
      ]);
      cart = result[0] as CartSnapshot;
      addresses = result[1] as List<AddressModel>;
      methods = result[2] as List<PaymentMethodModel>;
      currencies = result[3] as List<CurrencyModel>;
      paymentAccounts = result[4] as List<PaymentAccountModel>;
      checkoutBanners = result[5] as List<CheckoutBannerModel>;
      address = addresses.where((a) => a.isActive).cast<AddressModel?>().firstOrNull ??
          (addresses.isNotEmpty ? addresses.first : null);
      payment = null;
      currency = currencies.where((c) => c.code == preferred).cast<CurrencyModel?>().firstOrNull ??
          currencies.where((c) => c.code == (cart?.currencyCode ?? 'USD')).cast<CurrencyModel?>().firstOrNull ??
          (currencies.isNotEmpty ? currencies.first : null);
      if (currency != null) {
        cart = await ref.read(cartRepositoryProvider).updateMeta(currencyCode: currency!.code);
      }
      await _refreshQuote();
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
    if (!mounted) return;
    setState(() {
      addresses = list;
      address = selected;
      payment = null;
      quote = null;
    });
    await _refreshQuote();
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (busy || cart == null || address == null || payment == null || currency == null || quote == null) return;
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
              child: SizedBox(
                width: double.infinity,
                height: 43,
                child: FilledButton(onPressed: () => context.go('/'), child: const Text('العودة للتسوق')),
              ),
            ),
          ]),
        ),
      );
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    final panel = dark ? spikeDarkPanel : spikePanel;
    final cardColor = dark ? const Color(0xFF1D1D1D) : Colors.white;
    final hasAddress = address != null;
    final walletData = ref.watch(walletProvider).valueOrNull;
    final wallet = walletData?['wallet'];
    final spikeWalletBalance = double.tryParse('${wallet?['balance'] ?? 0}') ?? 0;
    final spikeWalletCurrency = '${wallet?['currency_code'] ?? 'USD'}'.toUpperCase();
    final ready = hasAddress && payment != null && currency != null && quote != null && payment?.method != 'wallet' && !busy;
    final delivery = quote == null ? null : quote!.shippingUsd * cart!.exchangeRateFromUsd;
    final productsBeforeDiscount = cart!.originalSubtotal;
    final discount = cart!.saving.clamp(0, double.infinity).toDouble();
    final productsAfterDiscount = cart!.subtotal;
    final grand = delivery == null ? null : productsAfterDiscount + delivery;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const _CheckoutHead(title: 'تأكيد الطلب والدفع'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(17, 4, 17, 24),
              children: [
                _AddressButton(address: address, onTap: _chooseAddress, cardColor: cardColor),
                if (checkoutBanners.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _CheckoutBanner(banner: checkoutBanners.first),
                ],
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(22)),
                  child: Row(children: [
                    const Icon(LucideIcons.truck, size: 18),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Text('تكلفة التوصيل يحددها النظام حسب التغطية والمتجر والمسافة', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                    Text(delivery == null ? 'جاري الحساب...' : delivery == 0 ? 'مجاني' : _money(delivery, cart!.currencyCode), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                  ]),
                ),
                if (quote != null && quote!.quotes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...quote!.quotes.map((q) => _ShippingLine(q: q, rate: cart!.exchangeRateFromUsd, currency: cart!.currencyCode)),
                ],
                const Padding(
                  padding: EdgeInsets.fromLTRB(5, 14, 5, 9),
                  child: Text('طريقة الدفع', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                Opacity(
                  opacity: hasAddress ? 1 : .42,
                  child: Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: methods.map((method) => _PaymentChoice(
                      method: method,
                      selected: payment?.method == method.method,
                      onTap: () {
                        if (!hasAddress) {
                          showSpikeToast(context, 'أضف أو اختر عنوان التوصيل');
                          return;
                        }
                        setState(() => payment = method);
                      },
                      cardColor: cardColor,
                    )).toList(),
                  ),
                ),
                if (!hasAddress)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('أضف أو اختر عنوان التوصيل أولاً لتفعيل طرق الدفع', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: spikeRed)),
                  ),
                if (payment?.method == 'transfer' && hasAddress) ...[
                  const SizedBox(height: 12),
                  _TransferAccounts(accounts: paymentAccounts, fallbackInstructions: payment?.instructions ?? '', cardColor: cardColor),
                ],
                if (payment?.method == 'wallet' && hasAddress) ...[
                  const SizedBox(height: 12),
                  _PaymentNotice(
                    icon: LucideIcons.walletCards,
                    title: 'محفظة إلكترونية',
                    text: 'هذا الخيار يعتمد على مزود محفظة خارجي. سيتم تفعيل إكمال الدفع بعد ربط مزود الدفع والتحقق الآمن.',
                    cardColor: cardColor,
                  ),
                ],
                if (payment?.method == 'spike_wallet' && hasAddress) ...[
                  const SizedBox(height: 12),
                  _SpikeWalletPanel(
                    balance: spikeWalletBalance,
                    currency: spikeWalletCurrency,
                    cardColor: cardColor,
                  ),
                ],
                const SizedBox(height: 13),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(22)),
                  child: Column(children: [
                    _InvoiceLine(label: 'إجمالي المنتجات', value: _money(productsBeforeDiscount, cart!.currencyCode)),
                    if (discount > 0) _InvoiceLine(label: 'الخصومات والكوبون', value: '- ${_money(discount, cart!.currencyCode)}'),
                    _InvoiceLine(label: 'المنتجات بعد الخصومات', value: _money(productsAfterDiscount, cart!.currencyCode)),
                    _InvoiceLine(label: 'التوصيل', value: delivery == null ? 'جاري الحساب...' : delivery == 0 ? 'مجاني' : _money(delivery, cart!.currencyCode)),
                    Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('الإجمالي التقديري', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(grand == null ? '—' : _money(grand, cart!.currencyCode), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    const Text('الإجمالي النهائي يعاد تثبيته من الخادم عند إنشاء الطلب.', style: TextStyle(fontSize: 9, color: spikeMuted)),
                  ]),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 43,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: spikeRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
                    onPressed: ready ? _submit : null,
                    icon: busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(LucideIcons.creditCard, size: 18),
                    label: const Text('تأكيد الطلب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  static String _money(double amount, String code) {
    final c = code.toUpperCase();
    if (c == 'USD') return '\$${amount.toStringAsFixed(2)}';
    if (c == 'SAR') return '${amount.toStringAsFixed(2)} ر.س';
    if (c.startsWith('YER')) return '${amount.round()} ر.ي';
    if (c == 'TRY') return '${amount.toStringAsFixed(2)} ₺';
    return '${amount.toStringAsFixed(2)} $c';
  }
}

class _AddressButton extends StatelessWidget {
  const _AddressButton({required this.address, required this.onTap, required this.cardColor});
  final AddressModel? address;
  final VoidCallback onTap;
  final Color cardColor;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: cardColor, border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Icon(LucideIcons.mapPin, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(address == null ? 'اختر عنوان التوصيل' : '${address!.label} - ${address!.cityName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
            const Text('تغيير', style: TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
          ]),
        ),
      );
}

class _CheckoutBanner extends StatelessWidget {
  const _CheckoutBanner({required this.banner});
  final CheckoutBannerModel banner;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 3.1,
          child: Image.network(banner.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ),
      );
}

class _PaymentChoice extends StatelessWidget {
  const _PaymentChoice({required this.method, required this.selected, required this.onTap, required this.cardColor});
  final PaymentMethodModel method;
  final bool selected;
  final VoidCallback onTap;
  final Color cardColor;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(17), border: Border.all(color: selected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).dividerColor)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, size: 18),
            const SizedBox(width: 7),
            Text(method.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _TransferAccounts extends StatelessWidget {
  const _TransferAccounts({required this.accounts, required this.fallbackInstructions, required this.cardColor});
  final List<PaymentAccountModel> accounts;
  final String fallbackInstructions;
  final Color cardColor;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: Theme.of(context).dividerColor)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('بيانات التحويل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (accounts.isEmpty)
            Text(fallbackInstructions.trim().isEmpty ? 'لا توجد حسابات دفع مضافة من الإدارة.' : fallbackInstructions, style: const TextStyle(fontSize: 10, height: 1.55))
          else
            ...accounts.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.name.isEmpty ? 'حوالة مالية' : a.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  if (a.accountName.isNotEmpty) Text('اسم الحساب: ${a.accountName}', style: const TextStyle(fontSize: 10)),
                  if (a.accountNumber.isNotEmpty) Text('رقم الحساب: ${a.accountNumber}', textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  if (a.instructions.isNotEmpty) Text(a.instructions, style: const TextStyle(fontSize: 9, color: spikeMuted)),
                ]),
              ),
            )),
          const Text('بعد إنشاء الطلب ارفع سند الحوالة من صفحة طلباتي، ثم تراجعه الإدارة قبل انتقال الطلب للمتجر.', style: TextStyle(fontSize: 9, color: spikeMuted, height: 1.5)),
        ]),
      );
}

class _PaymentNotice extends StatelessWidget {
  const _PaymentNotice({required this.icon, required this.title, required this.text, required this.cardColor});
  final IconData icon;
  final String title, text;
  final Color cardColor;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(fontSize: 10, color: spikeMuted, height: 1.5)),
            ]),
          ),
        ]),
      );
}

class _SpikeWalletPanel extends StatelessWidget {
  const _SpikeWalletPanel({required this.balance, required this.currency, required this.cardColor});
  final double balance;
  final String currency;
  final Color cardColor;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: spikeField, borderRadius: BorderRadius.circular(13)),
            child: const Icon(LucideIcons.wallet, size: 20),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('محفظة Spike', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              SizedBox(height: 3),
              Text('سيتم خصم قيمة الطلب مباشرة من رصيد محفظتك.', style: TextStyle(fontSize: 9, color: spikeMuted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('الرصيد المتاح', style: TextStyle(fontSize: 9, color: spikeMuted)),
            Text('${balance.toStringAsFixed(2)} $currency', textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ]),
      );
}

class _ShippingLine extends StatelessWidget {
  const _ShippingLine({required this.q, required this.rate, required this.currency});
  final Map<String, dynamic> q;
  final double rate;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final usd = double.tryParse('${q['shipping_usd'] ?? 0}') ?? 0;
    final distance = double.tryParse('${q['distance_km'] ?? ''}');
    final free = q['free_shipping_applied'] == true;
    final estimated = q['distance_estimated'] == true;
    final label = '${q['store_name'] ?? 'رسوم التوصيل'}${distance == null ? '' : ' (${distance.toStringAsFixed(1)} كم${estimated ? ' تقديري' : ''})'}';
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 10, color: spikeMuted))),
        Text(free ? 'مجاني' : _CheckoutScreenState._money(usd * rate, currency), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
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
                  child: InkWell(borderRadius: BorderRadius.circular(22), onTap: () => context.canPop() ? context.pop() : context.go('/cart'), child: const Icon(LucideIcons.arrowRight, size: 23)),
                ),
              ),
            ),
          ]),
        ),
      );
}

class _InvoiceLine extends StatelessWidget {
  const _InvoiceLine({required this.label, required this.value});
  final String label, value;
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
