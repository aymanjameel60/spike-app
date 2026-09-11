import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/password_reset_screen.dart';
import '../features/cart/presentation/cart_screen.dart';
import '../features/catalog/presentation/categories_screen.dart';
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
import '../features/offers/presentation/offers_screen.dart';
import '../features/orders/presentation/orders_screen.dart';
import '../features/orders/presentation/returns_refunds_screen.dart';
import '../features/profile/presentation/personal_data_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/privacy_screen.dart';
import '../features/profile/presentation/settings_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/shell/presentation/main_shell.dart';
import '../features/stores/presentation/store_details_screen.dart';
import '../features/stores/presentation/stores_screen.dart';

final appRouter=GoRouter(
  routes:[
    ShellRoute(
      builder:(context,state,child)=>MainShell(child:child,location:state.uri.path),
      routes:[
        GoRoute(path:'/',builder:(_,__)=>const HomeScreen()),
        GoRoute(path:'/offers',builder:(_,__)=>const OffersScreen()),
        GoRoute(path:'/cart',builder:(_,__)=>const CartScreen()),
        GoRoute(path:'/profile',builder:(_,__)=>const ProfileScreen()),
        GoRoute(path:'/personal-data',builder:(_,__)=>const PersonalDataScreen()),
        GoRoute(path:'/privacy',builder:(_,__)=>const PrivacyScreen()),
        GoRoute(path:'/settings',builder:(_,__)=>const SettingsScreen()),
        GoRoute(path:'/favorites',builder:(_,__)=>const FavoritesScreen()),
        GoRoute(path:'/checkout',builder:(_,__)=>const CheckoutScreen()),
        GoRoute(path:'/orders',builder:(_,__)=>const OrdersScreen()),
        GoRoute(path:'/order/:id',builder:(_,state)=>OrderDetailsScreen(id:state.pathParameters['id']!)),
        GoRoute(path:'/returns-refunds',builder:(_,__)=>const ReturnsRefundsScreen()),
        GoRoute(path:'/notifications',builder:(_,__)=>const NotificationsScreen()),
        GoRoute(path:'/reviews',builder:(_,__)=>const ReviewsScreen()),
        GoRoute(path:'/share-win',builder:(_,__)=>const ShareWinScreen()),
        GoRoute(path:'/support',builder:(_,__)=>const SupportChatScreen()),
        GoRoute(path:'/categories',builder:(_,__)=>const CategoriesScreen()),
        GoRoute(path:'/stores',builder:(_,__)=>const StoresScreen()),
        GoRoute(path:'/store/:id',builder:(_,state)=>StoreDetailsScreen(id:state.pathParameters['id']!)),
        GoRoute(path:'/products',builder:(_,state)=>ProductsScreen(categoryId:state.uri.queryParameters['category'],collectionId:state.uri.queryParameters['collection'],title:state.uri.queryParameters['title']??'المنتجات')),
        GoRoute(path:'/product/:id',builder:(_,state)=>ProductDetailsScreen(id:state.pathParameters['id']!)),
        GoRoute(path:'/search',builder:(_,state)=>SearchScreen(initialQuery:state.uri.queryParameters['q']??'')),
      ],
    ),
    GoRoute(path:'/addresses',builder:(_,__)=>const AddressesScreen()),
    GoRoute(path:'/address-form',builder:(_,state)=>AddressFormScreen(address:state.extra is AddressModel?state.extra as AddressModel:null)),
    GoRoute(path:'/password-reset',builder:(_,__)=>const PasswordResetScreen()),
    GoRoute(path:'/login',builder:(_,state)=>AuthScreen(mode:'login',afterLoginRoute:(state.uri.queryParameters['next']?.isNotEmpty??false)?state.uri.queryParameters['next']!:'/profile',referralCode:state.uri.queryParameters['ref']??'')),
    GoRoute(path:'/signup',builder:(_,state)=>AuthScreen(mode:'signup',afterLoginRoute:(state.uri.queryParameters['next']?.isNotEmpty??false)?state.uri.queryParameters['next']!:'/profile',referralCode:state.uri.queryParameters['ref']??'')),
  ],
  errorBuilder:(_,__)=>const Directionality(textDirection:TextDirection.rtl,child:Center(child:Text('الصفحة غير موجودة'))),
);
