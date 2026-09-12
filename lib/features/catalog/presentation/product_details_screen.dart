import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import '../../../core/widgets/spike_network_image.dart';
import '../../../models/product.dart';
import '../../../widgets/product_card.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  const ProductDetailsScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  int _galleryIndex = 0;
  String? _variantId;
  bool _favorite = false, _favoriteBusy = false;
  late Future<List<Map<String, dynamic>>> _reviews;
  Future<List<ProductModel>>? _similarProducts;
  String? _similarForProductId;

  @override
  void initState() {
    super.initState();
    _reviews = ref.read(engagementRepositoryProvider).productReviews(widget.id);
    _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    try {
      final ids = await ref.read(engagementRepositoryProvider).wishlistIds();
      if (mounted) setState(() => _favorite = ids.contains(widget.id));
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (_favoriteBusy) return;
    setState(() => _favoriteBusy = true);
    try {
      if (_favorite) {
        await ref.read(engagementRepositoryProvider).removeWishlist(widget.id);
      } else {
        await ref.read(engagementRepositoryProvider).addWishlist(widget.id);
      }
      ref.invalidate(wishlistIdsProvider);
      ref.invalidate(favoritesProvider);
      if (mounted) {
        setState(() => _favorite = !_favorite);
        showSpikeToast(context, _favorite ? 'تمت إضافة المنتج إلى المفضلة' : 'تمت إزالة المنتج من المفضلة');
      }
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  Future<void> _share(ProductModel p, ProductVariant v) async {
    final text = '${p.name}\n${_money(v.price, v.currency)}';
    try {
      await Share.share(text, subject: p.name);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) showSpikeToast(context, 'تم نسخ بيانات المنتج للمشاركة');
    }
  }

  Future<List<ProductModel>> _loadSimilarProducts(ProductModel product) async {
    final categoryId = product.categoryId?.trim() ?? '';
    if (categoryId.isEmpty) return const [];
    final page = await ref.read(catalogRepositoryProvider).pagedProducts(
          page: 1,
          pageSize: 12,
          categoryId: categoryId,
        );
    return page.items.where((item) => item.id != product.id).take(10).toList();
  }

  Future<List<ProductModel>> _similarFuture(ProductModel product) {
    if (_similarProducts == null || _similarForProductId != product.id) {
      _similarForProductId = product.id;
      _similarProducts = _loadSimilarProducts(product);
    }
    return _similarProducts!;
  }

  Future<void> _addSimilarToCart(ProductModel product) async {
    final variant = product.cheapestVariant;
    if (variant == null || variant.id.isEmpty || variant.stock <= 0) {
      showSpikeToast(context, 'هذا المنتج غير متوفر حالياً');
      return;
    }
    try {
      await ref.read(cartRepositoryProvider).add(variantId: variant.id, product: product);
      ref.invalidate(cartCountProvider);
      if (mounted) showSpikeToast(context, 'تمت إضافة المنتج إلى السلة');
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productProvider(widget.id));
    return Scaffold(
      body: SafeArea(
        child: state.when(
          loading: () => const SpikeLoading(),
          error: (e, _) => SpikeErrorState(message: e.toString(), onRetry: () => ref.invalidate(productProvider(widget.id))),
          data: (p) => p == null ? const SpikeEmptyState(message: 'المنتج غير متاح حالياً') : _body(p),
        ),
      ),
    );
  }

  Widget _body(ProductModel p) {
    final variants = p.variants;
    final selected = variants.firstWhere(
      (v) => v.id == _variantId,
      orElse: () => p.cheapestVariant ?? (variants.isNotEmpty ? variants.first : const ProductVariant(id: '', title: '', price: 0, stock: 0)),
    );
    _variantId ??= selected.id.isEmpty ? null : selected.id;
    final images = p.images.isNotEmpty ? p.images : [if (p.imageUrl != null) p.imageUrl!];
    final old = selected.originalPrice;
    final discount = old != null && old > selected.price && selected.price > 0 ? ((old - selected.price) / old * 100).round() : 0;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final block = dark ? const Color(0xFF17181B) : Colors.white;

    return Stack(children: [
      ListView(
        padding: const EdgeInsets.only(bottom: 105),
        children: [
          SizedBox(
            height: 60,
            child: Stack(alignment: Alignment.center, children: [
              const Text('تفاصيل المنتج', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 17),
                  child: IconButton(onPressed: () => context.canPop() ? context.pop() : context.go('/'), icon: const Icon(LucideIcons.arrowRight)),
                ),
              ),
            ]),
          ),
          SizedBox(
            height: 320,
            child: Stack(children: [
              PageView.builder(
                itemCount: images.isEmpty ? 1 : images.length,
                onPageChanged: (i) => setState(() => _galleryIndex = i),
                itemBuilder: (_, i) => Container(
                  color: block,
                  alignment: Alignment.center,
                  child: images.isEmpty
                      ? const Icon(LucideIcons.image, size: 60)
                      : FractionallySizedBox(widthFactor: .82, heightFactor: .82, child: SpikeNetworkImage(url: images[i], fit: BoxFit.contain)),
                ),
              ),
              Positioned(top: 16, right: 18, child: _action(LucideIcons.heart, onTap: _toggleFavorite)),
              Positioned(top: 16, left: 18, child: _action(LucideIcons.share2, onTap: () => _share(p, selected))),
              if (images.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      images.length,
                      (i) => Container(
                        width: i == _galleryIndex ? 14 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: i == _galleryIndex ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: .18),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          _block([
            if (p.storeId != null)
              InkWell(
                onTap: () => context.push('/store/${p.storeId}'),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    const Icon(LucideIcons.store, size: 17),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p.storeName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                    const Icon(LucideIcons.arrowLeft, size: 16),
                  ]),
                ),
              ),
            if (p.storeId != null) const SizedBox(height: 10),
            Text(p.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.28)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5B400)),
              const SizedBox(width: 4),
              Text(p.reviewCount > 0 && p.rating > 0 ? p.rating.toStringAsFixed(1) : '—', style: const TextStyle(fontWeight: FontWeight.w700)),
              if (p.reviewCount > 0) Text(' (${p.reviewCount} تقييم)', style: const TextStyle(fontSize: 11, color: spikeMuted)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              if (old != null && old > selected.price) ...[
                Text(_money(old, selected.currency), style: const TextStyle(fontSize: 11, color: spikeMuted, decoration: TextDecoration.lineThrough)),
                const SizedBox(width: 10),
              ],
              Text(_money(selected.price, selected.currency), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              if (discount > 0) ...[
                const SizedBox(width: 10),
                Text('خصم $discount%', style: const TextStyle(color: Color(0xFF2EAA49), fontWeight: FontWeight.w700)),
              ],
            ]),
            const SizedBox(height: 8),
            Text(
              selected.stock > 0 ? (selected.stock <= 5 ? 'متوفر — ${selected.stock} قطعة' : 'متوفر في المخزون') : 'غير متوفر حالياً',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ]),
          if (variants.length > 1)
            _block([
              const Text('اختر الخيار', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: variants
                    .map((v) => ChoiceChip(
                          label: Text('${v.title.isEmpty ? 'الخيار' : v.title}  ${_money(v.price, v.currency)}'),
                          selected: v.id == selected.id,
                          onSelected: (_) => setState(() => _variantId = v.id),
                        ))
                    .toList(),
              ),
            ]),
          if (p.storeId != null)
            _block([
              Row(children: [
                const Icon(LucideIcons.store, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('يباع بواسطة', style: TextStyle(fontSize: 9, color: spikeMuted)),
                    const SizedBox(height: 3),
                    Text(p.storeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                ),
                SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => context.push('/store/${p.storeId}'),
                    icon: const Icon(LucideIcons.store, size: 16),
                    label: const Text('زيارة المتجر', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ]),
          _block([
            const Text('تفاصيل المنتج', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Text((p.description ?? '').trim().isEmpty ? 'لا توجد تفاصيل إضافية لهذا المنتج حالياً.' : p.description!, style: const TextStyle(fontSize: 13, height: 1.8)),
            if (p.returnable)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Row(children: [
                  Icon(LucideIcons.rotateCcw, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text('هذا المنتج قابل للإرجاع حسب سياسة المتجر.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                ]),
              ),
          ]),
          _similarProductsBlock(p),
          _block([
            const Text('التقييمات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _reviews,
              builder: (context, s) {
                if (s.connectionState == ConnectionState.waiting) return const LinearProgressIndicator(minHeight: 2);
                final rows = s.data ?? const [];
                if (rows.isEmpty) return const Text('لا توجد تقييمات لهذا المنتج بعد.', style: TextStyle(fontSize: 11, color: spikeMuted));
                return Column(
                  children: rows.take(5).map((r) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${r['name'] ?? 'عميل'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: '${r['comment'] ?? ''}'.trim().isEmpty ? null : Text('${r['comment']}'),
                        trailing: Text('★ ${r['rating'] ?? '—'}'),
                      )).toList(),
                );
              },
            ),
          ]),
        ],
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(12),
            color: block,
            child: Row(children: [
              Expanded(child: Text(_money(selected.price, selected.currency), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: selected.id.isEmpty || selected.stock <= 0
                      ? null
                      : () async {
                          try {
                            await ref.read(cartRepositoryProvider).add(variantId: selected.id, product: p);
                            ref.invalidate(cartCountProvider);
                            if (context.mounted) showSpikeToast(context, 'تمت إضافة المنتج إلى السلة');
                          } catch (e) {
                            if (context.mounted) showSpikeToast(context, e.toString());
                          }
                        },
                  icon: const Icon(LucideIcons.shoppingBag, size: 18),
                  label: Text(selected.stock <= 0 ? 'غير متوفر' : 'إضافة إلى السلة'),
                ),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _similarProductsBlock(ProductModel product) {
    final categoryId = product.categoryId?.trim() ?? '';
    if (categoryId.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<List<ProductModel>>(
      future: _similarFuture(product),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _block(const [
            Text('منتجات مشابهة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 14),
            LinearProgressIndicator(minHeight: 2),
          ]);
        }
        if (snapshot.hasError) {
          return _block([
            const Text('منتجات مشابهة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Text('تعذر تحميل المنتجات المشابهة.', style: TextStyle(fontSize: 11, color: spikeMuted)),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _similarProducts = null;
                  _similarForProductId = null;
                }),
                icon: const Icon(LucideIcons.refreshCw, size: 15),
                label: const Text('إعادة المحاولة'),
              ),
            ),
          ]);
        }
        final items = snapshot.data ?? const <ProductModel>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return _block([
          const Text('منتجات مشابهة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          SizedBox(
            height: 275,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return SpikeProductCard(
                  product: item,
                  onTap: () => context.push('/product/${item.id}'),
                  onStore: (item.storeId ?? '').isEmpty ? null : () => context.push('/store/${item.storeId}'),
                  onAdd: () => _addSimilarToCart(item),
                );
              },
            ),
          ),
        ]);
      },
    );
  }

  Widget _block(List<Widget> children) => Container(
        margin: const EdgeInsets.fromLTRB(17, 12, 17, 0),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? spikeDarkPanel : Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  Widget _action(IconData icon, {required VoidCallback onTap}) => Material(
        color: Theme.of(context).colorScheme.surface,
        shape: const CircleBorder(),
        child: IconButton(onPressed: onTap, icon: Icon(icon, size: 20, color: _favorite && icon == LucideIcons.heart ? spikeRed : null)),
      );

  String _money(double amount, String currency) {
    final c = currency.toUpperCase();
    if (c == 'USD') return '\$${amount.toStringAsFixed(2)}';
    if (c == 'SAR') return '${amount.toStringAsFixed(2)} ر.س';
    if (c.startsWith('YER')) return '${amount.round()} ر.ي';
    if (c == 'TRY') return '${amount.toStringAsFixed(2)} ₺';
    return '${amount.toStringAsFixed(2)} $c';
  }
}
