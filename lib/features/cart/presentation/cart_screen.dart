import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/providers.dart';
import '../../../core/api_config.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import '../data/cart_repository.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});
  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _coupon = TextEditingController();
  CartSnapshot? _cart;
  bool _loading = true;
  bool _guest = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _coupon.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _guest = false; });
    try {
      final c = await ref.read(cartRepositoryProvider).load();
      ref.invalidate(cartCountProvider);
      if (mounted) {
        setState(() {
          _cart = c;
          _coupon.text = c.couponCode ?? '';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _qty(CartItemModel item, int qty) async {
    try {
      final c = await ref.read(cartRepositoryProvider).update(variantId: item.variantId, quantity: qty);
      ref.invalidate(cartCountProvider);
      if (mounted) setState(() => _cart = c);
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    }
  }

  String _money(double value, String currency) {
    final code = currency.trim().toUpperCase();
    final symbol = switch (code) { 'USD' => r'$', 'SAR' => 'ر.س', 'YER' => 'ر.ي', 'TRY' => '₺', _ => code };
    return '${value.toStringAsFixed(2)} $symbol'.trim();
  }

  String _asset(String raw) => ApiConfig.resolveMedia(raw);

  void _openBanner(Map<String, dynamic> b) {
    final type = '${b['target_type'] ?? ''}';
    final id = '${b['target_id'] ?? ''}';
    final url = '${b['target_url'] ?? ''}';
    if (type == 'product' && id.isNotEmpty) {
      context.push('/product/$id');
    } else if (type == 'category' && id.isNotEmpty) {
      context.push('/products?category=$id&title=المنتجات');
    } else if (type == 'collection' && id.isNotEmpty) {
      context.push('/products?collection=$id&title=المنتجات');
    } else if (type == 'store' && id.isNotEmpty) {
      context.push('/store/$id');
    } else if (type == 'internal' && url.startsWith('/')) {
      context.push(url);
    }
  }

  Widget _banner() {
    final state = ref.watch(cartBannersProvider);
    return state.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final b = items.first;
        final src = _asset('${b['image_url'] ?? ''}');
        if (src.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: InkWell(
            onTap: () => _openBanner(b),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(src, width: double.infinity, height: 54, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Color _panel(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? spikeDarkPanel : spikePanel;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SafeArea(child: SpikeLoading());
    final cart = _cart;
    if (cart == null) return SafeArea(child: SpikeErrorState(message: _error ?? 'تعذر تحميل بيانات السلة', onRetry: _load));

    if (cart.items.isEmpty) {
      return SafeArea(
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(17, 8, 17, 0), child: _Title()),
            const Expanded(child: SpikeEmptyState(message: 'حقيبة التسوق فارغة\nأضف منتجاتك المفضلة وارجع هنا لإتمام الطلب.')),
            Padding(
              padding: const EdgeInsets.all(17),
              child: SizedBox(
                width: double.infinity,
                height: 39,
                child: FilledButton(style: FilledButton.styleFrom(backgroundColor: spikeRed), onPressed: () => context.go('/'), child: const Text('ابدأ التسوق')),
              ),
            ),
          ],
        ),
      );
    }

    final groups = <String, List<CartItemModel>>{};
    for (final item in cart.items) {
      (groups[item.storeName] ??= []).add(item);
    }
    final active = ref.watch(activeAddressProvider).valueOrNull;
    String money(double v) => _money(v, cart.currencyCode);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(17, 8, 17, 12),
              children: [
                const _Title(),
                const SizedBox(height: 13),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(color: _panel(context), borderRadius: BorderRadius.circular(22)),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.mapPin, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('التوصيل إلى', style: TextStyle(fontSize: 10, color: spikeMuted)),
                            const SizedBox(height: 2),
                            Text(
                              active == null ? 'اختر عنوان التوصيل' : '${active.label} - ${active.cityName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/addresses'),
                        child: Text(active == null ? 'اختيار' : 'تغيير', style: const TextStyle(color: spikeRed, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 13),
                _banner(),
                for (final entry in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
                    child: InkWell(
                      onTap: entry.value.first.storeId.isEmpty ? null : () => context.push('/store/${entry.value.first.storeId}'),
                      child: Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(bottom: 13),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? spikeDarkPanel : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < entry.value.length; i++)
                          _Item(item: entry.value[i], onQty: (q) => _qty(entry.value[i], q), money: money, showDivider: i < entry.value.length - 1),
                      ],
                    ),
                  ),
                ],
                _couponBox(context, onSurface),
                _summary(context, cart, money),
              ],
            ),
          ),
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.fromLTRB(17, 13, 17, 8),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 43,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: spikeRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
                  onPressed: () async { final user=await ref.read(currentUserProvider.future); if (!context.mounted) return; if (user == null) { final login=await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('سجّل الدخول لإكمال الطلب'), content: const Text('يمكنك الاحتفاظ بالمنتجات في السلة، لكن يلزم تسجيل الدخول للمتابعة إلى الدفع.'), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('تراجع')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('تسجيل الدخول'))])); if (login == true && context.mounted) context.push('/login?next=%2Fcheckout'); return; } context.push('/checkout'); },
                  child: Text('متابعة إلى الدفع • ${money(cart.subtotal)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _couponBox(BuildContext context, Color onSurface) => Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(border: Border.all(color: onSurface.withValues(alpha: .22)), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('لديك كوبون؟', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 39,
                    child: TextField(
                      controller: _coupon,
                      decoration: InputDecoration(
                        hintText: 'أدخل الكود',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 11),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: onSurface.withValues(alpha: .15))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: onSurface.withValues(alpha: .25))),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 39,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111827), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)), padding: const EdgeInsets.symmetric(horizontal: 18)),
                    onPressed: () async {
                      try {
                        final c = await ref.read(cartRepositoryProvider).updateMeta(couponCode: _coupon.text);
                        if (!mounted) return;
                        setState(() => _cart = c);
                        showSpikeToast(context, _coupon.text.trim().isEmpty ? 'تم إزالة الكوبون' : 'تم تطبيق الكوبون');
                      } catch (e) {
                        if (mounted) showSpikeToast(context, e.toString());
                      }
                    },
                    child: const Text('تطبيق', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _summary(BuildContext context, CartSnapshot cart, String Function(double) money) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _panel(context), borderRadius: BorderRadius.circular(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('ملخص الطلب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _invoiceLine('إجمالي المنتجات', money(cart.originalSubtotal)),
            if (cart.saving > 0) _invoiceLine('الخصم', '- ${money(cart.saving)}'),
            _invoiceTotal('المجموع قبل الشحن', money(cart.subtotal)),
            if (cart.saving > 0)
              Container(
                height: 43,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFDCEEE3), borderRadius: BorderRadius.circular(22)),
                child: Text('وفرت ${money(cart.saving)}', style: const TextStyle(color: Color(0xFF176B36), fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      );

  Widget _invoiceLine(String a, String b) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .12)))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(a, style: const TextStyle(fontSize: 11)), Text(b, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))]),
        ),
      );

  Widget _invoiceTotal(String a, String b) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(a, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), Text(b, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))]),
      );
}

class _Title extends StatelessWidget {
  const _Title();
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 60,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Text('حقيبة التسوق', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            Align(alignment: Alignment.centerRight, child: IconButton(onPressed: () => context.canPop() ? context.pop() : context.go('/'), icon: const Icon(LucideIcons.arrowRight, size: 22))),
          ],
        ),
      );
}

class _Item extends StatelessWidget {
  const _Item({required this.item, required this.onQty, required this.money, required this.showDivider});
  final CartItemModel item;
  final ValueChanged<int> onQty;
  final String Function(double) money;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final discount = item.originalPrice > item.unitPrice && item.unitPrice > 0 ? ((1 - item.unitPrice / item.originalPrice) * 100).round() : 0;
    final placeholder = Theme.of(context).colorScheme.onSurface.withValues(alpha: .22);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: showDivider ? BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .08)))) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => context.push('/product/${item.productId}'),
            borderRadius: BorderRadius.circular(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 100,
                height: 118,
                color: Theme.of(context).brightness == Brightness.dark ? spikeDarkPanel : const Color(0xFFF6F6F6),
                child: item.imageUrl == null ? Icon(LucideIcons.image, color: placeholder) : Image.network(item.imageUrl!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(LucideIcons.image, color: placeholder)),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(onTap: () => context.push('/product/${item.productId}'), child: Text(item.productName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                if (item.storeName.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: InkWell(onTap: item.storeId.isEmpty ? null : () => context.push('/store/${item.storeId}'), child: Text(item.storeName, style: const TextStyle(fontSize: 9, color: spikeMuted)))),
                if (item.variantTitle.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(item.variantTitle, style: const TextStyle(fontSize: 9, color: spikeMuted))),
                const SizedBox(height: 7),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: [
                      Text(money(item.unitPrice), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      if (discount > 0) ...[
                        const SizedBox(width: 7),
                        Text(money(item.originalPrice), style: const TextStyle(fontSize: 9, color: spikeMuted, decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 7),
                        Text('خصم $discount%', style: const TextStyle(fontSize: 9, color: spikeRed)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 88),
                      child: Container(
                        height: 31,
                        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 28, height: 31, child: IconButton(padding: EdgeInsets.zero, onPressed: () => onQty(item.quantity - 1), icon: const Icon(Icons.remove, size: 15))),
                            SizedBox(width: 30, child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
                            SizedBox(width: 28, height: 31, child: IconButton(padding: EdgeInsets.zero, onPressed: item.quantity < item.stock ? () => onQty(item.quantity + 1) : null, icon: const Icon(Icons.add, size: 15))),
                          ],
                        ),
                      ),
                    ),
                    TextButton.icon(style: TextButton.styleFrom(foregroundColor: spikeRed, padding: EdgeInsets.zero), onPressed: () => onQty(0), icon: const Icon(LucideIcons.trash2, size: 15), label: const Text('حذف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _GuestCart extends StatelessWidget {
  const _GuestCart({required this.onLogin});
  final VoidCallback onLogin;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(LucideIcons.shoppingBag, size: 52),
      const SizedBox(height: 16),
      const Text('سجّل الدخول لعرض حقيبة التسوق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      const Text('سيتم حفظ منتجاتك ومتابعة طلبك من حسابك.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: spikeMuted)),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 38, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: spikeRed), onPressed: onLogin, child: const Text('تسجيل الدخول'))),
    ]),
  );
}
