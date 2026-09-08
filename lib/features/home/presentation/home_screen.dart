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
    ref.watch(currenciesProvider);
    final announcements = ref.watch(announcementsProvider).valueOrNull ?? const <Map<String, dynamic>>[];
    final unreadNotifications = ref.watch(unreadNotificationsProvider);
    ref.watch(wishlistIdsProvider);

    return SafeArea(
      child: home.when(
        loading: () => const SpikeLoading(),
        error: (e, _) => SpikeErrorState(message: e.toString(), onRetry: () => ref.invalidate(homeDataProvider)),
        data: (data) {
          final offers = data.products.where(_hasOffer).toList();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(homeDataProvider);
              ref.invalidate(addressesProvider);
              ref.invalidate(wishlistIdsProvider);
              ref.invalidate(announcementsProvider);
              ref.invalidate(notificationsDataProvider);
              ref.invalidate(cartCountProvider);
              await ref.read(homeDataProvider.future);
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _Header(
                  logoUrl: brandingLogo,
                  address: activeAddress == null ? 'اختر عنوان التوصيل' : '${activeAddress.cityName} - ${activeAddress.label}',
                  currency: _currencySymbol(settings.currency),
                  unread: unreadNotifications,
                  onSearch: () => context.push('/search'),
                  onAddress: () => context.push('/addresses'),
                  onNotifications: () => context.push('/notifications'),
                  onCurrency: _openCurrencySheet,
                  onMenu: () => Scaffold.of(context).openEndDrawer(),
                ),
                if (announcements.isNotEmpty)
                  _AnnouncementCard(
                    item: announcements.first,
                    onDismiss: () => _dismissAnnouncement('${announcements.first['id'] ?? ''}'),
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
                const SizedBox(height: 32),
                _SectionTitle(title: 'تسوق حسب الفئة', showAll: data.categories.isNotEmpty, onShowAll: () => context.push('/categories')),
                _CategoriesGrid(
                  categories: data.categories.take(8).toList(),
                  onTap: (c) => context.push('/products?category=${Uri.encodeComponent(c.id)}&title=${Uri.encodeComponent(c.name)}'),
                ),
                const SizedBox(height: 32),
                _SectionTitle(title: 'مختارة لك', showAll: data.products.isNotEmpty, onShowAll: () => context.push('/products')),
                _productsStrip(products: data.products, emptyMessage: 'لا توجد منتجات منشورة بعد'),
                if (data.bestSellers.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  const _SectionTitle(title: 'الأكثر مبيعًا', showAll: false),
                  _productsStrip(products: data.bestSellers, emptyMessage: 'لا توجد مبيعات مكتملة بعد'),
                ],
                if (offers.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _SectionTitle(title: 'العروض والخصومات', showAll: true, onShowAll: () => context.push('/offers')),
                  _productsStrip(products: offers, emptyMessage: 'لا توجد عروض حالياً'),
                ],
                if (data.collections.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  const _SectionTitle(title: 'المجموعات', showAll: false),
                  _CollectionsStrip(
                    collections: data.collections,
                    onTap: (c) {
                      final type = (c.destinationType ?? '').toLowerCase();
                      final id = c.destinationId ?? '';
                      if (id.isEmpty) return;
                      if (type == 'product') {
                        context.push('/product/$id');
                      } else if (type == 'category') {
                        context.push('/products?category=${Uri.encodeComponent(id)}&title=${Uri.encodeComponent(c.name)}');
                      } else if (type == 'collection') {
                        context.push('/products?collection=${Uri.encodeComponent(id)}&title=${Uri.encodeComponent(c.name)}');
                      }
                    },
                  ),
                ],
                const SizedBox(height: 32),
                _SectionTitle(title: 'المتاجر', showAll: data.stores.isNotEmpty, onShowAll: () => context.push('/stores')),
                _StoresStrip(stores: data.stores, onTap: (s) => context.push('/store/${s.id}')),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _dismissAnnouncement(String id) async {
    if (id.isEmpty) return;
    try {
      await ref.read(engagementRepositoryProvider).dismissAnnouncement(id);
      ref.invalidate(announcementsProvider);
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    }
  }

  bool _hasOffer(ProductModel p) {
    final v = p.cheapestVariant;
    return v != null && v.originalPrice != null && v.originalPrice! > v.price && v.price > 0;
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

  void _openBanner(BannerItem item) {
    final t = item.actionType.toLowerCase();
    if (t == 'product' && item.target.isNotEmpty) {
      context.push('/product/${item.target}');
    } else if (t == 'category' && item.target.isNotEmpty) {
      context.push('/products?category=${Uri.encodeComponent(item.target)}');
    } else if (t == 'collection' && item.target.isNotEmpty) {
      context.push('/products?collection=${Uri.encodeComponent(item.target)}');
    } else if (t == 'store' && item.target.isNotEmpty) {
      context.push('/store/${item.target}');
    } else if (t == 'internal' && item.targetUrl.startsWith('/')) {
      context.push(item.targetUrl);
    }
  }

  Future<void> _openCurrencySheet() async {
    final currencies = ref.read(currenciesProvider).valueOrNull ?? const [];
    final current = ref.read(appSettingsProvider).currency;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 10, 17, 22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 42, height: 4, decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 14),
            Row(children: [
              const Expanded(child: Text('اختر العملة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
              IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(LucideIcons.x, size: 20)),
            ]),
            if (currencies.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('لا توجد عملات متاحة حالياً', style: TextStyle(fontSize: 10, color: spikeMuted)),
              ),
            for (final c in currencies)
              ListTile(
                minTileHeight: 58,
                contentPadding: const EdgeInsets.symmetric(horizontal: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: BorderSide(color: current == c.code ? Theme.of(context).colorScheme.onSurface : Theme.of(context).dividerColor)),
                title: Text(c.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                subtitle: Text(c.code, style: const TextStyle(fontSize: 8)),
                trailing: Icon(current == c.code ? Icons.radio_button_checked : Icons.radio_button_off, size: 19),
                onTap: () async {
                  await ref.read(appSettingsProvider.notifier).setCurrency(c.code);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
          ]),
        ),
      ),
    );
  }

  Future<void> _add(ProductModel p) async {
    if (!p.purchasable || p.cheapestVariant == null) return;
    try {
      await ref.read(cartRepositoryProvider).add(variantId: p.cheapestVariant!.id, product: p);
      ref.invalidate(cartCountProvider);
      if (mounted) showSpikeToast(context, 'تمت إضافة المنتج إلى السلة');
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    }
  }

  Future<void> _toggleFavorite(ProductModel p) async {
    if (_favoriteBusy.contains(p.id)) return;
    setState(() => _favoriteBusy.add(p.id));
    final current = ref.read(wishlistIdsProvider).valueOrNull ?? <String>{};
    final active = current.contains(p.id);
    try {
      if (active) {
        await ref.read(engagementRepositoryProvider).removeWishlist(p.id);
      } else {
        await ref.read(engagementRepositoryProvider).addWishlist(p.id);
      }
      ref.invalidate(wishlistIdsProvider);
      ref.invalidate(favoritesProvider);
      if (mounted) showSpikeToast(context, active ? 'تمت إزالة المنتج من المفضلة' : 'تمت إضافة المنتج إلى المفضلة');
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    } finally {
      if (mounted) setState(() => _favoriteBusy.remove(p.id));
    }
  }

  Widget _productsStrip({required List<ProductModel> products, required String emptyMessage}) {
    final favorites = ref.watch(wishlistIdsProvider).valueOrNull ?? <String>{};
    return SizedBox(
      height: 246,
      child: products.isEmpty
          ? SpikeEmptyState(message: emptyMessage)
          : ListView.separated(
              reverse: true,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 17),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final p = products[i];
                return SpikeProductCard(
                  product: p,
                  isFavorite: favorites.contains(p.id),
                  onTap: () => context.push('/product/${p.id}'),
                  onAdd: !p.purchasable || p.cheapestVariant == null ? null : () => _add(p),
                  onFavorite: _favoriteBusy.contains(p.id) ? null : () => _toggleFavorite(p),
                  onStore: p.storeId == null ? null : () => context.push('/store/${p.storeId}'),
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
    required this.onMenu,
  });

  final String? logoUrl;
  final String address;
  final String currency;
  final int unread;
  final VoidCallback onSearch;
  final VoidCallback onAddress;
  final VoidCallback onNotifications;
  final VoidCallback onCurrency;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final field = Theme.of(context).brightness == Brightness.dark ? spikeDarkPanel : spikeField;
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 8, 17, 0),
      child: Column(children: [
        SizedBox(
          height: 64,
          child: Row(children: [
            SizedBox(width: 53, height: 38, child: Center(child: logoUrl == null ? const Text('SPIKE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -.5)) : CachedNetworkImage(imageUrl: logoUrl!, fit: BoxFit.contain, errorWidget: (_, __, ___) => const Text('SPIKE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -.5))))),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton(
                onPressed: onAddress,
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface, padding: EdgeInsets.zero),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.chevronDown, size: 18),
                  const SizedBox(width: 5),
                  Flexible(child: Text(address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                IconButton(onPressed: onNotifications, icon: const Icon(LucideIcons.bell, size: 22)),
                if (unread > 0)
                  Positioned(
                    right: 0,
                    top: -3,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: spikeRed, shape: BoxShape.circle),
                      child: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: onSearch,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                height: 39,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: field, borderRadius: BorderRadius.circular(22)),
                child: const Row(children: [
                  Icon(LucideIcons.search, size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text('ابحث عن المنتجات ...', style: TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)))),
                ]),
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
              decoration: BoxDecoration(color: field, borderRadius: BorderRadius.circular(22)),
              child: Text(currency, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item, required this.onDismiss});

  final Map<String, dynamic> item;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(17, 16, 17, 0),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: spikeRed.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? .14 : .08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: spikeRed.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? .28 : .15)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(LucideIcons.megaphone, size: 18, color: spikeRed)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${item['title'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              if ('${item['body'] ?? ''}'.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text('${item['body']}', style: const TextStyle(fontSize: 10, height: 1.5))),
            ]),
          ),
          IconButton(onPressed: onDismiss, icon: const Icon(LucideIcons.x, size: 17), visualDensity: VisualDensity.compact),
        ]),
      );
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    height: 130,
    margin: const EdgeInsets.fromLTRB(18, 16, 18, 0),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(23),
    ),
  );
}

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.items, required this.controller, required this.index, required this.onPageChanged, required this.onTap});

  final List<BannerItem> items;
  final PageController controller;
  final int index;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<BannerItem> onTap;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _remaining(BannerItem item) {
    final end = item.endsAt;
    if (!item.countdown || end == null) return '';
    final d = end.toLocal().difference(DateTime.now());
    if (d.isNegative) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
        child: Column(children: [
          SizedBox(
            height: 130,
            child: PageView.builder(
              controller: widget.controller,
              itemCount: widget.items.length,
              onPageChanged: widget.onPageChanged,
              itemBuilder: (context, i) {
                final item = widget.items[i];
                final remaining = _remaining(item);
                return GestureDetector(
                  onTap: () => widget.onTap(item),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(23),
                    child: Stack(fit: StackFit.expand, children: [
                      CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        width: double.infinity,
                        height: 130,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .08)),
                      ),
                      if (remaining.isNotEmpty)
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .72), borderRadius: BorderRadius.circular(14)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(LucideIcons.clock3, size: 14, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(remaining, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                            ]),
                          ),
                        ),
                    ]),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 22,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.items.length,
                (i) => Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == widget.index ? Theme.of(context).colorScheme.onSurface.withValues(alpha: .35) : Theme.of(context).colorScheme.onSurface.withValues(alpha: .12),
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.showAll, this.onShowAll});

  final String title;
  final bool showAll;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        child: SizedBox(
          height: 48,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            if (showAll) TextButton(style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface), onPressed: onShowAll, child: const Text('عرض الكل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          ]),
        ),
      );
}

class _CategoriesGrid extends StatelessWidget {
  const _CategoriesGrid({required this.categories, required this.onTap});

  final List<CategoryModel> categories;
  final ValueChanged<CategoryModel> onTap;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SpikeEmptyState(message: 'لا توجد أقسام منشورة بعد');
    final placeholderColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: .22);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 11,
          mainAxisSpacing: 16,
          mainAxisExtent: 120,
        ),
        itemBuilder: (context, i) {
          final c = categories[i];
          return InkWell(
            onTap: () => onTap(c),
            borderRadius: BorderRadius.circular(21),
            child: Column(children: [
              Container(
                width: 81,
                height: 81,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(21)),
                child: c.imageUrl == null
                    ? Icon(LucideIcons.image, color: placeholderColor)
                    : CachedNetworkImage(imageUrl: c.imageUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => Icon(LucideIcons.image, color: placeholderColor)),
              ),
              const SizedBox(height: 7),
              Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.2)),
            ]),
          );
        },
      ),
    );
  }
}

class _CollectionsStrip extends StatelessWidget {
  const _CollectionsStrip({required this.collections, required this.onTap});

  final List<CollectionModel> collections;
  final ValueChanged<CollectionModel> onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 113,
        child: ListView.separated(
          reverse: true,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(17, 4, 17, 8),
          itemCount: collections.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final c = collections[i];
            return GestureDetector(
              onTap: () => onTap(c),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 153,
                  height: 101,
                  child: c.imageUrl == null
                      ? Container(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .08))
                      : CachedNetworkImage(imageUrl: c.imageUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .08))),
                ),
              ),
            );
          },
        ),
      );
}

class _StoresStrip extends StatelessWidget {
  const _StoresStrip({required this.stores, required this.onTap});

  final List<StoreModel> stores;
  final ValueChanged<StoreModel> onTap;

  @override
  Widget build(BuildContext context) {
    if (stores.isEmpty) return const SpikeEmptyState(message: 'لا توجد متاجر منشورة بعد');
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 69,
      child: ListView.separated(
        reverse: true,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 17),
        itemCount: stores.length,
        separatorBuilder: (_, __) => const SizedBox(width: 11),
        itemBuilder: (context, i) {
          final store = stores[i];
          return InkWell(
            onTap: () => onTap(store),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 154,
              height: 69,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: dark ? spikeDarkPanel : const Color(0xFFE9E9E9), borderRadius: BorderRadius.circular(22)),
              child: store.logoUrl == null
                  ? Text(store.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: CachedNetworkImage(
                        imageUrl: store.logoUrl!,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => Text(store.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
