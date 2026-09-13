import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/password_reset_screen.dart';
import '../features/cart/presentation/cart_screen.dart';
import '../features/catalog/presentation/categories_screen.dart';
import '../features/catalog/presentation/category_screen.dart';
import '../features/catalog/presentation/product_details_screen.dart';
import '../features/catalog/presentation/products_screen.dart';
import '../features/checkout/data/commerce_repository.dart';
import '../features/checkout/presentation/addresses_screen.dart';
import '../features/checkout/presentation/checkout_screen.dart';
import '../features/engagement/presentation/notifications_screen.dart';
import '../features/engagement/presentation/reviews_screen.dart';
import '../features/engagement/presentation/share_win_screen.dart';
import '../features/engagement/presentation/support_chat_screen.dart';
import '../features/favorites/presentation/favorites_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/home_section_screen.dart';
import '../features/offers/presentation/offers_screen.dart';
import '../features/orders/presentation/orders_screen.dart';
import '../features/orders/presentation/returns_refunds_screen.dart';
import '../features/profile/presentation/personal_data_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/privacy_screen.dart';
import '../features/profile/presentation/settings_screen.dart';
import '../features/profile/presentation/vendor_registration_screen.dart';
import '../features/profile/presentation/wallet_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/shell/presentation/main_shell.dart';
import '../features/stores/presentation/store_details_screen.dart';
import '../features/stores/presentation/stores_screen.dart';

const _recentProductsKey = 'spike-recently-viewed';

void _rememberProduct(String id) {
  final value = id.trim();
  if (value.isEmpty) return;
  SharedPreferences.getInstance().then((prefs) async {
    final current = prefs.getStringList(_recentProductsKey) ?? const <String>[];
    final next = <String>[value, ...current.where((item) => item != value)].take(12).toList();
    await prefs.setStringList(_recentProductsKey, next);
  });
}

NoTransitionPage<void> _page(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

AuthScreen _auth(GoRouterState state, String mode) => AuthScreen(
      mode: mode,
      afterLoginRoute: (state.uri.queryParameters['next']?.isNotEmpty ?? false)
          ? state.uri.queryParameters['next']!
          : '/profile',
      referralCode: state.uri.queryParameters['ref'] ?? '',
    );

final appRouter = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          MainShell(child: child, location: state.uri.path),
      routes: [
        GoRoute(path: '/', pageBuilder: (_, state) => _page(state, const HomeScreen())),
        GoRoute(path: '/offers', pageBuilder: (_, state) => _page(state, const OffersScreen())),
        GoRoute(path: '/cart', pageBuilder: (_, state) => _page(state, const CartScreen())),
        GoRoute(path: '/profile', pageBuilder: (_, state) => _page(state, const ProfileScreen())),
        GoRoute(path: '/login', pageBuilder: (_, state) => _page(state, _auth(state, 'login'))),
        GoRoute(path: '/signup', pageBuilder: (_, state) => _page(state, _auth(state, 'signup'))),
        GoRoute(path: '/personal-data', pageBuilder: (_, state) => _page(state, const PersonalDataScreen())),
        GoRoute(path: '/privacy', pageBuilder: (_, state) => _page(state, const PrivacyScreen())),
        GoRoute(path: '/settings', pageBuilder: (_, state) => _page(state, const SettingsScreen())),
        GoRoute(path: '/favorites', pageBuilder: (_, state) => _page(state, const FavoritesScreen())),
        GoRoute(path: '/wallet', pageBuilder: (_, state) => _page(state, const WalletScreen())),
        GoRoute(path: '/vendor-registration', pageBuilder: (_, state) => _page(state, const VendorRegistrationScreen())),
        GoRoute(path: '/checkout', pageBuilder: (_, state) => _page(state, const CheckoutScreen())),
        GoRoute(path: '/orders', pageBuilder: (_, state) => _page(state, const OrdersScreen())),
        GoRoute(path: '/order/:id', pageBuilder: (_, state) => _page(state, OrderDetailsScreen(id: state.pathParameters['id']!))),
        GoRoute(path: '/returns-refunds', pageBuilder: (_, state) => _page(state, const ReturnsRefundsScreen())),
        GoRoute(path: '/notifications', pageBuilder: (_, state) => _page(state, const NotificationsScreen())),
        GoRoute(path: '/reviews', pageBuilder: (_, state) => _page(state, const ReviewsScreen())),
        GoRoute(path: '/share-win', pageBuilder: (_, state) => _page(state, const ShareWinScreen())),
        GoRoute(path: '/support', pageBuilder: (_, state) => _page(state, const SupportChatScreen())),
        GoRoute(path: '/addresses', pageBuilder: (_, state) => _page(state, const AddressesScreen())),
        GoRoute(path: '/address-form', pageBuilder: (_, state) => _page(state, AddressFormScreen(address: state.extra is AddressModel ? state.extra as AddressModel : null))),
        GoRoute(path: '/categories', pageBuilder: (_, state) => _page(state, const CategoriesScreen())),
        GoRoute(path: '/category/:id', pageBuilder: (_, state) => _page(state, CategoryScreen(id: state.pathParameters['id']!))),
        GoRoute(path: '/stores', pageBuilder: (_, state) => _page(state, const StoresScreen())),
        GoRoute(path: '/section/:id', pageBuilder: (_, state) => _page(state, HomeSectionScreen(id: state.pathParameters['id']!))),
        GoRoute(path: '/store/:id', pageBuilder: (_, state) => _page(state, StoreDetailsScreen(id: state.pathParameters['id']!))),
        GoRoute(
          path: '/products',
          pageBuilder: (_, state) {
            final categoryId = state.uri.queryParameters['category'];
            if ((categoryId ?? '').isNotEmpty) {
              return _page(state, CategoryScreen(id: categoryId!));
            }
            return _page(
              state,
              ProductsScreen(
                key: ValueKey('products:${state.uri}'),
                collectionId: state.uri.queryParameters['collection'],
                title: state.uri.queryParameters['title'] ?? 'المنتجات',
              ),
            );
          },
        ),
        GoRoute(
          path: '/product/:id',
          pageBuilder: (_, state) {
            final id = state.pathParameters['id']!;
            _rememberProduct(id);
            return _page(state, ProductDetailsScreen(id: id));
          },
        ),
        GoRoute(path: '/search', pageBuilder: (_, state) => _page(state, SearchScreen(initialQuery: state.uri.queryParameters['q'] ?? ''))),
      ],
    ),
    GoRoute(path: '/password-reset', pageBuilder: (_, state) => _page(state, const PasswordResetScreen())),
  ],
  errorBuilder: (_, __) => const Directionality(
    textDirection: TextDirection.rtl,
    child: Center(child: Text('الصفحة غير موجودة')),
  ),
);
