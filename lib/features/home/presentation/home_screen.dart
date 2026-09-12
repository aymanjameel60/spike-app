import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import '../../../models/banner_item.dart';
import '../../../models/category.dart';
import '../../../models/collection.dart';
import '../../../models/product.dart';
import '../../../models/store.dart';
import '../../../widgets/product_card.dart';
import '../../checkout/data/commerce_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _bannerController = PageController();
  final Set<String> _favoriteBusy = {};
  int _bannerIndex = 0;

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeDataProvider);
    final activeAddress = ref.watch(activeAddressProvider).valueOrNull;
    final brandingLogo = ref.watch(brandingLogoProvider).valueOrNull;
    final settings = ref.watch(appSettingsProvider);
    final liveOffers = ref.watch(offersProductsProvider);
    ref.watch(currenciesProvider);
    final unreadNotifications = ref.watch(unreadNotificationsProvider);
    ref.watch(wishlistIdsProvider);

    return SafeArea(
      child: home.when(
        loading: () => const _HomeSkeleton(),
        error: (e, _) => SpikeErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(homeDataProvider),
        ),
        data: (data) {
          final offers = liveOffers.valueOrNull ??
              data.products.where(_hasOffer).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(homeDataProvider);
              ref.invalidate(addressesProvider);
              ref.invalidate(wishlistIdsProvider);
              ref.invalidate(notificationsDataProvider);
              ref.invalidate(cartCountProvider);
              ref.invalidate(offersProductsProvider);
              await ref.read(homeDataProvider.future);
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _Header(
                  logoUrl: brandingLogo,
                  address: _deliveryAddressLabel(activeAddress),
                  currency: _currencySymbol(settings.currency),
                  unread: unreadNotifications,
                  onSearch: () => context.push('/search'),
                  onAddress: () => context.push('/addresses'),
                  onNotifications: () => context.push('/notifications'),
                  onCurrency: _openCurrencySheet,
                ),
                if (data.banners.isNotEmpty)
                  _BannerCarousel(
                    items: data.banners,
                    controller: _bannerController,
                    index: _bannerIndex,
                    onPageChanged: (i) => setState(() => _bannerIndex = i),
                    onTap: _openBanner,
                  )
                else
                  const _BannerPlaceholder(),
                _SectionTitle(
                  title: 'تسوق حسب الفئة',
                  showAll: data.categories.isNotEmpty,
                  onShowAll: () => context.push('/categories'),
                ),
                _CategoriesGrid(
                  categories: data.categories.take(8).toList(),
                  onTap: _openHomeCategory,
                ),
                const SizedBox(height: 18),
                _SectionTitle(
                  title: 'المنتجات',
                  showAll: data.products.isNotEmpty,
                  onShowAll: () => context.push('/products'),
                ),
                _productsStrip(
                  products: data.products,
                  emptyMessage: 'لا توجد منتجات منشورة بعد',
                ),
                const SizedBox(height: 18),
                if (offers.isNotEmpty) ...[
                  _SectionTitle(
                    title: 'العروض والخصومات',
                    showAll: true,
                    onShowAll: () => context.push('/offers'),
                  ),
                  _productsStrip(
                    products: offers,
                    emptyMessage: 'لا توجد عروض حالياً',
                  ),
                  const SizedBox(height: 18),
                ],
                if (data.collections.isNotEmpty) ...[
                  const _SectionTitle(
                    title: 'المجموعات',
                    showAll: false,
                  ),
                  _CollectionsStrip(
                    collections: data.collections,
                    onTap: _openCollection,
                  ),
                  const SizedBox(height: 18),
                ],
                _SectionTitle(
                  title: 'المتاجر',
                  showAll: data.stores.isNotEmpty,
                  onShowAll: () => context.push('/stores'),
                ),
                _StoresStrip(
                  stores: data.stores,
                  onTap: (store) => context.push('/store/${store.id}'),
                ),
                const SizedBox(height: 18),
              ],
            ),
          );
        },
      ),
    );
  }

  String _deliveryAddressLabel(AddressModel? address) {
    if (address == null) return 'اختر عنوان التوصيل';
    final city = address.cityName.trim();
    final details = address.addressLine.trim();
    final label = address.label.trim();
    final parts = <String>[];
    if (city.isNotEmpty && city.toLowerCase() != 'undefined') parts.add(city);
    if (details.isNotEmpty &&
        details.toLowerCase() != 'undefined' &&
        !parts.contains(details)) {
      parts.add(details);
    }
    if (parts.isEmpty && label.isNotEmpty && label.toLowerCase() != 'undefined') {
      parts.add(label);
    }
    return parts.isEmpty ? 'اختر عنوان التوصيل' : parts.join(' - ');
  }

  bool _hasOffer(ProductModel product) {
    final variant = product.cheapestVariant;
    return variant != null &&
        variant.originalPrice != null &&
        variant.originalPrice! > variant.price &&
        variant.price > 0;
  }

  String _currencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'SAR':
        return 'ر.س';
      case 'USD':
        return r'$';
      case 'YER':
      case 'YER_OLD':
        return 'ر.ي';
      case 'TRY':
        return '₺';
      default:
        return code.toUpperCase();
    }
  }

  void _openHomeCategory(CategoryModel category) {
    final actionType = category.actionType.trim().toLowerCase();
    final target = (category.actionTarget ?? '').trim();

    if (category.showAsMore || actionType == 'all_categories') {
      context.push('/categories');
      return;
    }
    if (actionType == 'section' && target.isNotEmpty) {
      context.push('/section/${Uri.encodeComponent(target)}');
      return;
    }
    if (actionType == 'collection' && target.isNotEmpty) {
      context.push(
        '/products?collection=${Uri.encodeComponent(target)}&title=${Uri.encodeComponent(category.name)}',
      );
      return;
    }

    final categoryId = target.isNotEmpty ? target : category.id;
    context.push('/category/${Uri.encodeComponent(categoryId)}');
  }

  void _openCollection(CollectionModel collection) {
    final type = (collection.destinationType ?? '').toLowerCase();
    final id = collection.destinationId ?? '';
    if (id.isEmpty) return;
    if (type == 'product') {
      context.push('/product/$id');
    } else if (type == 'category') {
      context.push('/category/${Uri.encodeComponent(id)}');
    } else if (type == 'collection') {
      context.push(
        '/products?collection=${Uri.encodeComponent(id)}&title=${Uri.encodeComponent(collection.name)}',
      );
    }
  }

  void _openBanner(BannerItem item) {
    final type = item.actionType.toLowerCase();
    if (type == 'product' && item.target.isNotEmpty) {
      context.push('/product/${item.target}');
    } else if (type == 'category' && item.target.isNotEmpty) {
      context.push('/category/${Uri.encodeComponent(item.target)}');
    } else if (type == 'collection' && item.target.isNotEmpty) {
      context.push(
        '/products?collection=${Uri.encodeComponent(item.target)}',
      );
    } else if (type == 'store' && item.target.isNotEmpty) {
      context.push('/store/${item.target}');
    } else if (type == 'internal' && item.targetUrl.startsWith('/')) {
      context.push(item.targetUrl);
    }
  }

  Future<void> _openCurrencySheet() async {
    final currencies = ref.read(currenciesProvider).valueOrNull ?? const [];
    final current = ref.read(appSettingsProvider).currency;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final panel = dark ? spikeDarkPanel : const Color(0xFFE9E9E9);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 10, 17, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'اختر العملة',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Material(
                    color: panel,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.pop(sheetContext),
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(LucideIcons.x, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (currencies.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: const Text(
                    'لا توجد عملات متاحة حالياً',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: spikeMuted),
                  ),
                )
              else
                for (var i = 0; i < currencies.length; i++) ...[
                  _CurrencyOption(
                    currency: currencies[i],
                    selected: current == currencies[i].code,
                    panelColor: panel,
                    onTap: () async {
                      await ref
                          .read(appSettingsProvider.notifier)
                          .setCurrency(currencies[i].code);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                  ),
                  if (i != currencies.length - 1) const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _add(ProductModel product) async {
    if (!product.purchasable || product.cheapestVariant == null) return;
    try {
      await ref.read(cartRepositoryProvider).add(
            variantId: product.cheapestVariant!.id,
            product: product,
          );
      ref.invalidate(cartCountProvider);
      if (mounted) showSpikeToast(context, 'تمت إضافة المنتج إلى السلة');
    } catch (error) {
      if (mounted) showSpikeToast(context, error.toString());
    }
  }

  Future<void> _toggleFavorite(ProductModel product) async {
    if (_favoriteBusy.contains(product.id)) return;
    setState(() => _favoriteBusy.add(product.id));
    final current = ref.read(wishlistIdsProvider).valueOrNull ?? <String>{};
    final active = current.contains(product.id);
    try {
      if (active) {
        await ref
            .read(engagementRepositoryProvider)
            .removeWishlist(product.id);
      } else {
        await ref.read(engagementRepositoryProvider).addWishlist(product.id);
      }
      ref.invalidate(wishlistIdsProvider);
      ref.invalidate(favoritesProvider);
      if (mounted) {
        showSpikeToast(
          context,
          active
              ? 'تمت إزالة المنتج من المفضلة'
              : 'تمت إضافة المنتج إلى المفضلة',
        );
      }
    } catch (error) {
      if (mounted) showSpikeToast(context, error.toString());
    } finally {
      if (mounted) setState(() => _favoriteBusy.remove(product.id));
    }
  }

  Widget _productsStrip({
    required List<ProductModel> products,
    required String emptyMessage,
  }) {
    final favorites = ref.watch(wishlistIdsProvider).valueOrNull ?? <String>{};
    return SizedBox(
      height: 246,
      child: products.isEmpty
          ? SpikeEmptyState(message: emptyMessage)
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 17),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final product = products[index];
                return SpikeProductCard(
                  product: product,
                  isFavorite: favorites.contains(product.id),
                  onTap: () => context.push('/product/${product.id}'),
                  onAdd: !product.purchasable ||
                          product.cheapestVariant == null
                      ? null
                      : () => _add(product),
                  onFavorite: _favoriteBusy.contains(product.id)
                      ? null
                      : () => _toggleFavorite(product),
                  onStore: product.storeId == null
                      ? null
                      : () => context.push('/store/${product.storeId}'),
                );
              },
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    this.logoUrl,
    required this.address,
    required this.currency,
    required this.unread,
    required this.onSearch,
    required this.onAddress,
    required this.onNotifications,
    required this.onCurrency,
  });

  final String? logoUrl;
  final String address;
  final String currency;
  final int unread;
  final VoidCallback onSearch;
  final VoidCallback onAddress;
  final VoidCallback onNotifications;
  final VoidCallback onCurrency;

  @override
  Widget build(BuildContext context) {
    final field = Theme.of(context).brightness == Brightness.dark
        ? spikeDarkPanel
        : spikeField;
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 8, 17, 0),
      child: Column(
        children: [
          SizedBox(
            height: 64,
            child: Row(
              children: [
                SizedBox(
                  width: 53,
                  height: 38,
                  child: Center(
                    child: logoUrl == null
                        ? const Text(
                            'SPIKE',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: -.5,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: logoUrl!,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => const Text(
                              'SPIKE',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: -.5,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: onAddress,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      padding: EdgeInsets.zero,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.chevronDown, size: 18),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        onPressed: onNotifications,
                        icon: const Icon(LucideIcons.bell, size: 22),
                      ),
                      if (unread > 0)
                        Positioned(
                          right: 0,
                          top: -3,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: spikeRed,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onSearch,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    height: 39,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: field,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.search, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'ابحث عن المنتجات ...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFBDBDBD),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              InkWell(
                onTap: onCurrency,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 53,
                  height: 39,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: field,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    currency,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurrencyOption extends StatelessWidget {
  const _CurrencyOption({
    required this.currency,
    required this.selected,
    required this.panelColor,
    required this.onTap,
  });

  final CurrencyModel currency;
  final bool selected;
  final Color panelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: panelColor,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).dividerColor,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currency.name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currency.code,
                        style: const TextStyle(
                          fontSize: 8,
                          color: spikeMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.onSurface
                          : spikeMuted,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? Center(
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      );
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        height: 130,
        margin: const EdgeInsets.fromLTRB(18, 16, 18, 22),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: .06),
          borderRadius: BorderRadius.circular(23),
        ),
      );
}

class _BannerImagePlaceholder extends StatefulWidget {
  const _BannerImagePlaceholder();

  @override
  State<_BannerImagePlaceholder> createState() =>
      _BannerImagePlaceholderState();
}

class _BannerImagePlaceholderState extends State<_BannerImagePlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final alpha = .05 + (_controller.value * .05);
          return ColoredBox(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: alpha),
          );
        },
      );
}

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({
    required this.items,
    required this.controller,
    required this.index,
    required this.onPageChanged,
    required this.onTap,
  });

  final List<BannerItem> items;
  final PageController controller;
  final int index;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<BannerItem> onTap;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  Timer? _autoplayTimer;

  @override
  void initState() {
    super.initState();
    _startAutoplay();
  }

  @override
  void didUpdateWidget(covariant _BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _startAutoplay();
    }
  }

  void _startAutoplay() {
    _autoplayTimer?.cancel();
    if (widget.items.length < 2) return;
    _autoplayTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted ||
          !widget.controller.hasClients ||
          widget.items.length < 2) {
        return;
      }
      final current = widget.controller.page?.round() ?? widget.index;
      final next = (current + 1) % widget.items.length;
      widget.controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoplayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
        child: Column(
          children: [
            SizedBox(
              height: 130,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: PageView.builder(
                  controller: widget.controller,
                  itemCount: widget.items.length,
                  onPageChanged: widget.onPageChanged,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    return GestureDetector(
                      onTap: () => widget.onTap(item),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(23),
                        child: CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          width: double.infinity,
                          height: 130,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const _BannerImagePlaceholder(),
                          errorWidget: (_, __, ___) =>
                              const _BannerImagePlaceholder(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(
              height: 22,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.items.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == widget.index ? 14 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: index == widget.index
                          ? const Color(0xFFAAAAAA)
                          : const Color(0xFFD2D2D2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.showAll,
    this.onShowAll,
  });

  final String title;
  final bool showAll;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showAll)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: onShowAll,
                  child: const Text(
                    'عرض الكل',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _CategoriesGrid extends StatelessWidget {
  const _CategoriesGrid({
    required this.categories,
    required this.onTap,
  });

  final List<CategoryModel> categories;
  final ValueChanged<CategoryModel> onTap;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SpikeEmptyState(message: 'لا توجد أقسام منشورة بعد');
    }
    final placeholderColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: .22);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 11,
          mainAxisSpacing: 13,
          mainAxisExtent: 118,
        ),
        itemBuilder: (context, index) {
          final category = categories[index];
          return InkWell(
            onTap: () => onTap(category),
            borderRadius: BorderRadius.circular(21),
            child: Column(
              children: [
                Container(
                  width: 81,
                  height: 81,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(21),
                  ),
                  child: category.imageUrl == null
                      ? Icon(LucideIcons.image, color: placeholderColor)
                      : CachedNetworkImage(
                          imageUrl: category.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              Icon(LucideIcons.image, color: placeholderColor),
                        ),
                ),
                const SizedBox(height: 7),
                Text(
                  category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CollectionsStrip extends StatelessWidget {
  const _CollectionsStrip({
    required this.collections,
    required this.onTap,
  });

  final List<CollectionModel> collections;
  final ValueChanged<CollectionModel> onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 113,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(17, 4, 17, 8),
          itemCount: collections.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final collection = collections[index];
            return GestureDetector(
              onTap: () => onTap(collection),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 153,
                  height: 101,
                  child: collection.imageUrl == null
                      ? Container(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: .08),
                        )
                      : CachedNetworkImage(
                          imageUrl: collection.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: .08),
                          ),
                        ),
                ),
              ),
            );
          },
        ),
      );
}

class _StoresStrip extends StatelessWidget {
  const _StoresStrip({
    required this.stores,
    required this.onTap,
  });

  final List<StoreModel> stores;
  final ValueChanged<StoreModel> onTap;

  @override
  Widget build(BuildContext context) {
    if (stores.isEmpty) {
      return const SpikeEmptyState(message: 'لا توجد متاجر منشورة بعد');
    }
    return SizedBox(
      height: 69,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 17),
        itemCount: stores.length,
        separatorBuilder: (_, __) => const SizedBox(width: 11),
        itemBuilder: (context, index) {
          final store = stores[index];
          return InkWell(
            onTap: () => onTap(store),
            borderRadius: BorderRadius.circular(25),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: SizedBox(
                width: 153,
                height: 69,
                child: store.logoUrl == null
                    ? Center(
                        child: Text(
                          store.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: store.logoUrl!,
                        fit: BoxFit.cover,
                        width: 153,
                        height: 69,
                        errorWidget: (_, __, ___) => Center(
                          child: Text(
                            store.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HomeSkeleton extends StatefulWidget {
  const _HomeSkeleton();

  @override
  State<_HomeSkeleton> createState() => _HomeSkeletonState();
}

class _HomeSkeletonState extends State<_HomeSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final color = Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: .055 + (_controller.value * .045));
          Widget box({
            double? width,
            required double height,
            double radius = 12,
          }) =>
              Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(radius),
                ),
              );

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 8, 17, 0),
                child: Column(
                  children: [
                    SizedBox(
                      height: 64,
                      child: Row(
                        children: [
                          box(width: 53, height: 38, radius: 10),
                          const SizedBox(width: 8),
                          Expanded(child: box(height: 14, radius: 7)),
                          const SizedBox(width: 8),
                          box(width: 44, height: 44, radius: 22),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(child: box(height: 39, radius: 22)),
                        const SizedBox(width: 9),
                        box(width: 53, height: 39, radius: 22),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                child: box(height: 130, radius: 23),
              ),
              _SkeletonTitle(color: color, leftWidth: 72, rightWidth: 132),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 8,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 11,
                    mainAxisSpacing: 13,
                    mainAxisExtent: 118,
                  ),
                  itemBuilder: (_, __) => Column(
                    children: [
                      box(width: 81, height: 81, radius: 21),
                      const SizedBox(height: 7),
                      box(width: 62, height: 10, radius: 5),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _SkeletonTitle(color: color, leftWidth: 0, rightWidth: 90),
              SizedBox(
                height: 246,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, __) => SizedBox(
                    width: 154,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        box(width: 154, height: 134, radius: 22),
                        const SizedBox(height: 10),
                        box(width: 126, height: 12, radius: 6),
                        const SizedBox(height: 8),
                        box(width: 90, height: 10, radius: 5),
                        const SizedBox(height: 8),
                        box(width: 66, height: 14, radius: 7),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _SkeletonTitle(color: color, leftWidth: 72, rightWidth: 74),
              SizedBox(
                height: 69,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  itemCount: 2,
                  separatorBuilder: (_, __) => const SizedBox(width: 11),
                  itemBuilder: (_, __) => box(
                    width: 153,
                    height: 69,
                    radius: 25,
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
          );
        },
      );
}

class _SkeletonTitle extends StatelessWidget {
  const _SkeletonTitle({
    required this.color,
    required this.leftWidth,
    required this.rightWidth,
  });

  final Color color;
  final double leftWidth;
  final double rightWidth;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (rightWidth > 0)
                Container(
                  width: rightWidth,
                  height: 18,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              const Spacer(),
              if (leftWidth > 0)
                Container(
                  width: leftWidth,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
            ],
          ),
        ),
      );
}
