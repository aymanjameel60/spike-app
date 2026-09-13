import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import '../../../core/widgets/spike_network_image.dart';
import '../../../models/banner_item.dart';
import '../../../models/product.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _offerSeenKey = 'spike-badge-seen:offers';
  static bool _popupShownThisSession = false;
  bool _popupScheduled = false;
  bool _offerSeenLoaded = false;
  Set<String> _seenOfferTokens = <String>{};

  @override
  void initState() {
    super.initState();
    _loadOfferSeen();
  }

  Future<void> _loadOfferSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_offerSeenKey) ?? const <String>[];
    if (!mounted) return;
    setState(() {
      _seenOfferTokens = values.toSet();
      _offerSeenLoaded = true;
    });
  }

  String _offerToken(ProductModel product) {
    final original = product.originalPrice ?? 0;
    final current = product.price;
    final percent = original > current && current > 0
        ? (((original - current) / original) * 100).round()
        : 0;
    return '${product.id}:$current:$original:$percent';
  }

  Future<void> _markOffersSeen(List<ProductModel> products) async {
    final tokens = products.map(_offerToken).toSet();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_offerSeenKey, tokens.toList());
    if (!mounted) return;
    setState(() {
      _seenOfferTokens = tokens;
      _offerSeenLoaded = true;
    });
  }

  int get _index {
    final location = widget.location;
    if (location.startsWith('/offers')) return 1;
    if (location.startsWith('/cart') || location.startsWith('/checkout')) {
      return 3;
    }
    if (const [
      '/profile',
      '/login',
      '/signup',
      '/personal-data',
      '/privacy',
      '/settings',
      '/delete-account',
      '/favorites',
      '/orders',
      '/order/',
      '/returns-refunds',
      '/support',
      '/share-win',
      '/wallet',
      '/vendor-registration',
    ].any(location.startsWith)) {
      return 0;
    }
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cartCount = ref.watch(cartCountProvider).valueOrNull ?? 0;
    final offerProducts = ref.watch(offersProductsProvider).valueOrNull ??
        const <ProductModel>[];
    final offerTokens = offerProducts.map(_offerToken).toSet();
    final unseenOffers = _offerSeenLoaded
        ? offerTokens.where((token) => !_seenOfferTokens.contains(token)).length
        : 0;
    final popup = ref.watch(popupBannersProvider);

    if (!_popupShownThisSession && !_popupScheduled && widget.location == '/') {
      final items = popup.valueOrNull ?? const <BannerItem>[];
      if (items.isNotEmpty) {
        _popupScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showPopup(items.first),
        );
      }
    }

    return Scaffold(
      endDrawer: const _SpikeDrawer(),
      body: widget.child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: dark ? spikeDarkPanel : Colors.white,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Builder(
            builder: (shellContext) => Row(
              children: [
                _item(shellContext, 0, LucideIcons.userRound, '/profile'),
                _item(
                  shellContext,
                  1,
                  LucideIcons.badgePercent,
                  '/offers',
                  badge: unseenOffers,
                  beforeNavigate: () => _markOffersSeen(offerProducts),
                ),
                _item(shellContext, 2, LucideIcons.home, '/'),
                _item(
                  shellContext,
                  3,
                  LucideIcons.shoppingBag,
                  '/cart',
                  badge: cartCount,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPopup(BannerItem item) async {
    if (!mounted || _popupShownThisSession) return;
    _popupShownThisSession = true;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.of(dialogContext).pop();
                _openBanner(item);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: .86,
                  child: SpikeNetworkImage(
                    url: item.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -14,
              left: -8,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(
                    LucideIcons.x,
                    color: Colors.black,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _item(
    BuildContext context,
    int index,
    IconData icon,
    String route, {
    int badge = 0,
    VoidCallback? beforeNavigate,
  }) {
    final selected = _index == index;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Expanded(
      child: InkWell(
        onTap: () {
          beforeNavigate?.call();
          if (!selected) context.push(route);
        },
        child: Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: 23,
                  color: selected
                      ? onSurface
                      : onSurface.withValues(alpha: .38),
                ),
                if (badge > 0)
                  Positioned(
                    left: 2,
                    top: 2,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 15,
                        minHeight: 15,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: spikeRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpikeDrawer extends ConsumerWidget {
  const _SpikeDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final name = user == null
        ? 'مرحباً بك في Spike'
        : (user['name'] ?? 'حسابي').toString();
    return Drawer(
      backgroundColor: dark ? spikeDarkPanel : Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 14, 20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, size: 22),
                  ),
                  const Spacer(),
                  const Text(
                    'SPIKE',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.5,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (user == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: SizedBox(
                  height: 38,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: spikeRed),
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/login');
                    },
                    child: const Text('تسجيل الدخول'),
                  ),
                ),
              )
            else
              const SizedBox(height: 16),
            Divider(color: Theme.of(context).dividerColor, height: 1),
            const SizedBox(height: 8),
            _DrawerItem(
              icon: LucideIcons.home,
              label: 'الرئيسية',
              onTap: () => _go(context, '/'),
            ),
            _DrawerItem(
              icon: LucideIcons.store,
              label: 'المتاجر',
              onTap: () => _go(context, '/stores'),
            ),
            _DrawerItem(
              icon: LucideIcons.badgePercent,
              label: 'العروض والخصومات',
              onTap: () => _go(context, '/offers'),
            ),
            _DrawerItem(
              icon: LucideIcons.heart,
              label: 'المفضلة',
              onTap: () => _go(context, '/favorites'),
            ),
            _DrawerItem(
              icon: LucideIcons.mapPin,
              label: 'عناويني',
              onTap: () => _protectedGo(context, user, '/addresses'),
            ),
            _DrawerItem(
              icon: LucideIcons.messageCircle,
              label: 'خدمة العملاء',
              onTap: () => _go(context, '/support'),
            ),
            const Spacer(),
            _DrawerItem(
              icon: LucideIcons.settings2,
              label: 'الإعدادات',
              onTap: () => _go(context, '/settings'),
            ),
            if (user != null)
              _DrawerItem(
                icon: LucideIcons.logOut,
                label: 'تسجيل الخروج',
                onTap: () => _logout(context, ref),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    Navigator.pop(context);
    await ref.read(authRepositoryProvider).logout();
    ref.invalidate(currentUserProvider);
    ref.invalidate(hasSessionProvider);
    ref.invalidate(shareWinPublicProvider);
    if (context.mounted) context.go('/');
  }

  void _go(BuildContext context, String route) {
    Navigator.pop(context);
    context.go(route);
  }

  void _protectedGo(
    BuildContext context,
    Map<String, dynamic>? user,
    String route,
  ) {
    Navigator.pop(context);
    if (user == null) {
      showSpikeToast(context, 'سجّل الدخول أولاً للمتابعة');
      context.push('/login?next=${Uri.encodeComponent(route)}');
    } else {
      context.go(route);
    }
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, size: 21),
        title: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 22),
      );
}
