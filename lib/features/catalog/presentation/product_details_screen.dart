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
import '../../../core/widgets/spike_network_image.dart';
import '../../../models/product.dart';
import '../../../widgets/product_card.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  const ProductDetailsScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  int _galleryIndex = 0;
  String? _variantId;
  bool _favorite = false;
  bool _favoriteBusy = false;
  bool _followed = false;
  final Set<String> _cartVariantIds = <String>{};
  late Future<List<Map<String, dynamic>>> _reviews;
  Future<List<ProductModel>>? _similarProducts;
  String? _similarForProductId;

  @override
  void initState() {
    super.initState();
    _resetAsyncState();
  }

  @override
  void didUpdateWidget(covariant ProductDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id == widget.id) return;
    _galleryIndex = 0;
    _variantId = null;
    _favorite = false;
    _followed = false;
    _similarProducts = null;
    _similarForProductId = null;
    _resetAsyncState();
  }

  void _resetAsyncState() {
    _reviews = ref.read(engagementRepositoryProvider).productReviews(widget.id);
    _loadFavorite();
    _loadCartVariants();
  }

  Future<void> _loadFavorite() async {
    try {
      final ids = await ref.read(engagementRepositoryProvider).wishlistIds();
      if (mounted) setState(() => _favorite = ids.contains(widget.id));
    } catch (_) {}
  }

  Future<void> _loadCartVariants() async {
    try {
      final cart = await ref.read(cartRepositoryProvider).load();
      if (!mounted) return;
      setState(() {
        _cartVariantIds
          ..clear()
          ..addAll(cart.items.map((item) => item.variantId));
      });
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
        showSpikeToast(
          context,
          _favorite
              ? 'تمت إضافة المنتج إلى المفضلة'
              : 'تمت إزالة المنتج من المفضلة',
        );
      }
    } catch (error) {
      if (mounted) showSpikeToast(context, error.toString());
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  Future<void> _share(ProductModel product) async {
    final url =
        '${ApiConfig.customerWebBaseUrl}/#product:${Uri.encodeComponent(product.id)}';
    final text = product.storeName.trim().isEmpty
        ? product.name
        : '${product.name} - ${product.storeName}';
    try {
      await Share.share('$text\n$url', subject: product.name);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) showSpikeToast(context, 'تم نسخ رابط المنتج');
    }
  }

  Future<List<ProductModel>> _loadSimilarProducts(ProductModel product) async {
    final repo = ref.read(catalogRepositoryProvider);
    final picked = <ProductModel>[];
    final seen = <String>{product.id};

    void add(Iterable<ProductModel> items) {
      for (final item in items) {
        if (seen.add(item.id)) picked.add(item);
        if (picked.length >= 10) break;
      }
    }

    final categoryId = product.categoryId?.trim() ?? '';
    if (categoryId.isNotEmpty) {
      try {
        final page = await repo.pagedProducts(
          page: 1,
          pageSize: 24,
          categoryId: categoryId,
        );
        add(page.items);
      } catch (_) {}
    }

    final storeId = product.storeId?.trim() ?? '';
    if (picked.length < 10 && storeId.isNotEmpty) {
      try {
        final page = await repo.pagedProducts(
          page: 1,
          pageSize: 24,
          storeId: storeId,
        );
        add(page.items);
      } catch (_) {}
    }

    if (picked.length < 10) {
      try {
        final page = await repo.pagedProducts(page: 1, pageSize: 24);
        add(page.items);
      } catch (_) {}
    }
    return picked.take(10).toList();
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
      await ref.read(cartRepositoryProvider).add(
            variantId: variant.id,
            product: product,
          );
      ref.invalidate(cartCountProvider);
      if (mounted) showSpikeToast(context, 'تمت إضافة المنتج إلى السلة');
    } catch (error) {
      if (mounted) showSpikeToast(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productProvider(widget.id));
    return Scaffold(
      body: SafeArea(
        child: state.when(
          loading: () => const SpikeLoading(),
          error: (error, _) => SpikeErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(productProvider(widget.id)),
          ),
          data: (product) => product == null
              ? const SpikeEmptyState(message: 'المنتج غير متاح حالياً')
              : _body(product),
        ),
      ),
    );
  }

  Widget _body(ProductModel product) {
    final variants = product.variants;
    final selected = variants.firstWhere(
      (variant) => variant.id == _variantId,
      orElse: () => product.cheapestVariant ??
          (variants.isNotEmpty
              ? variants.first
              : const ProductVariant(
                  id: '',
                  title: '',
                  price: 0,
                  stock: 0,
                )),
    );
    _variantId ??= selected.id.isEmpty ? null : selected.id;
    final images = product.images.isNotEmpty
        ? product.images
        : [if (product.imageUrl != null) product.imageUrl!];
    final old = selected.originalPrice;
    final discount = old != null && old > selected.price && selected.price > 0
        ? ((old - selected.price) / old * 100).round()
        : 0;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final block = dark ? const Color(0xFF17181B) : Colors.white;
    final inCart =
        selected.id.isNotEmpty && _cartVariantIds.contains(selected.id);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 105),
          children: [
            SizedBox(
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    'تفاصيل المنتج',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 17),
                      child: IconButton(
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go('/'),
                        icon: const Icon(LucideIcons.arrowRight),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 320,
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: images.isEmpty ? 1 : images.length,
                    onPageChanged: (index) =>
                        setState(() => _galleryIndex = index),
                    itemBuilder: (_, index) => Container(
                      color: block,
                      alignment: Alignment.center,
                      child: images.isEmpty
                          ? const Icon(LucideIcons.image, size: 60)
                          : FractionallySizedBox(
                              widthFactor: .82,
                              heightFactor: .82,
                              child: SpikeNetworkImage(
                                url: images[index],
                                fit: BoxFit.contain,
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 18,
                    child: _action(
                      LucideIcons.heart,
                      onTap: _toggleFavorite,
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 18,
                    child: _action(
                      LucideIcons.share2,
                      onTap: () => _share(product),
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 14,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          images.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: index == _galleryIndex ? 14 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: index == _galleryIndex
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: .18),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _block([
              if (product.storeId != null)
                InkWell(
                  onTap: () => context.push('/store/${product.storeId}'),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.store, size: 17),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            product.storeName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(LucideIcons.arrowLeft, size: 16),
                      ],
                    ),
                  ),
                ),
              if (product.storeId != null) const SizedBox(height: 10),
              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.28,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: Color(0xFFF5B400),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    product.reviewCount > 0 && product.rating > 0
                        ? product.rating.toStringAsFixed(1)
                        : '—',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    product.reviewCount > 0
                        ? '(${product.reviewCount} تقييم)'
                        : 'لا توجد تقييمات بعد',
                    style: const TextStyle(fontSize: 11, color: spikeMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (old != null && old > selected.price) ...[
                    Text(
                      _money(old, selected.currency),
                      style: const TextStyle(
                        fontSize: 11,
                        color: spikeMuted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    selected.price > 0
                        ? _money(selected.price, selected.currency)
                        : '—',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (discount > 0) ...[
                    const SizedBox(width: 10),
                    Text(
                      'خصم $discount%',
                      style: const TextStyle(
                        color: Color(0xFF2EAA49),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    selected.stock > 0
                        ? LucideIcons.checkCircle
                        : LucideIcons.xCircle,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selected.stock >= 999999
                        ? 'متوفر في المخزون'
                        : selected.stock > 0
                            ? 'متوفر — ${selected.stock} قطعة'
                            : 'غير متوفر حالياً',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ]),
            if (variants.length > 1)
              _block([
                const Text(
                  'اختر الخيار',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: variants
                      .map(
                        (variant) => ChoiceChip(
                          label: Text(
                            '${variant.title.isEmpty ? 'الخيار' : variant.title}  ${_money(variant.price, variant.currency)}',
                          ),
                          selected: variant.id == selected.id,
                          onSelected: variant.stock <= 0
                              ? null
                              : (_) => setState(() => _variantId = variant.id),
                        ),
                      )
                      .toList(),
                ),
              ]),
            if (product.storeId != null)
              _block([
                Row(
                  children: [
                    const Icon(LucideIcons.store, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'يباع بواسطة',
                            style: TextStyle(fontSize: 9, color: spikeMuted),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            product.storeName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () =>
                              context.push('/store/${product.storeId}'),
                          icon: const Icon(LucideIcons.store, size: 16),
                          label: const Text(
                            'زيارة المتجر',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _followed = !_followed),
                          icon: Icon(
                            _followed ? LucideIcons.check : LucideIcons.plus,
                            size: 16,
                          ),
                          label: Text(
                            _followed ? 'متابَع' : 'متابعة',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ]),
            _block([
              const Text(
                'تفاصيل المنتج',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Text(
                (product.description ?? '').trim().isEmpty
                    ? 'لا توجد تفاصيل إضافية لهذا المنتج حالياً.'
                    : product.description!,
                style: const TextStyle(fontSize: 13, height: 1.8),
              ),
            ]),
            _reviewsBlock(),
            _similarProductsBlock(product),
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
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selected.price > 0
                          ? _money(selected.price, selected.currency)
                          : '—',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: inCart
                        ? FilledButton.icon(
                            onPressed: () => context.push('/cart'),
                            icon: const Icon(LucideIcons.shoppingBag, size: 18),
                            label: const Text('الانتقال إلى السلة'),
                          )
                        : FilledButton.icon(
                            onPressed: selected.id.isEmpty ||
                                    selected.stock <= 0 ||
                                    selected.price <= 0
                                ? null
                                : () => _addToCart(product, selected),
                            icon: const Icon(LucideIcons.shoppingBag, size: 18),
                            label: Text(
                              selected.stock <= 0
                                  ? 'غير متوفر'
                                  : selected.id.isEmpty
                                      ? 'اختر خياراً'
                                      : selected.price <= 0
                                          ? 'السعر غير متاح'
                                          : 'إضافة إلى السلة',
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addToCart(
    ProductModel product,
    ProductVariant selected,
  ) async {
    try {
      await ref.read(cartRepositoryProvider).add(
            variantId: selected.id,
            product: product,
          );
      ref.invalidate(cartCountProvider);
      if (!mounted) return;
      setState(() => _cartVariantIds.add(selected.id));
      showSpikeToast(context, 'تمت إضافة المنتج إلى السلة');
    } catch (error) {
      if (mounted) showSpikeToast(context, error.toString());
    }
  }

  Widget _reviewsBlock() => _block([
        const Text(
          'التقييمات',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _reviews,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator(minHeight: 2);
            }
            final rows = snapshot.data ?? const <Map<String, dynamic>>[];
            if (rows.isEmpty) {
              return const Text(
                'لا توجد تقييمات من المشترين بعد.',
                style: TextStyle(fontSize: 11, color: spikeMuted),
              );
            }
            return Column(
              children: rows.take(10).map((review) {
                final comment = '${review['comment'] ?? ''}'.trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${review['name'] ?? 'عميل'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Text(
                                  'مشتري موثّق',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: spikeMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Color(0xFFF5B400),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${review['rating'] ?? '—'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          comment,
                          style: const TextStyle(fontSize: 11, height: 1.55),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ]);

  Widget _similarProductsBlock(ProductModel product) {
    return FutureBuilder<List<ProductModel>>(
      future: _similarFuture(product),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _block(const [
            Text(
              'منتجات مشابهة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 14),
            LinearProgressIndicator(minHeight: 2),
          ]);
        }
        final items = snapshot.data ?? const <ProductModel>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return _block([
          const Text(
            'منتجات مشابهة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          const Text(
            'منتجات أخرى قد تعجبك',
            style: TextStyle(fontSize: 10, color: spikeMuted),
          ),
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
                  onStore: (item.storeId ?? '').isEmpty
                      ? null
                      : () => context.push('/store/${item.storeId}'),
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
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? spikeDarkPanel
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );

  Widget _action(IconData icon, {required VoidCallback onTap}) => Material(
        color: Theme.of(context).colorScheme.surface,
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onTap,
          icon: Icon(
            icon,
            size: 20,
            color: _favorite && icon == LucideIcons.heart ? spikeRed : null,
          ),
        ),
      );

  String _money(double amount, String currency) {
    final code = currency.toUpperCase();
    if (code == 'USD') return '\$${amount.toStringAsFixed(2)}';
    if (code == 'SAR') return '${amount.toStringAsFixed(2)} ر.س';
    if (code.startsWith('YER')) return '${amount.round()} ر.ي';
    if (code == 'TRY') return '${amount.toStringAsFixed(2)} ₺';
    return '${amount.toStringAsFixed(2)} $code';
  }
}
