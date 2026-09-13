import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import '../../checkout/data/commerce_repository.dart';
import 'orders_screen.dart';

class OrdersGateScreen extends ConsumerStatefulWidget {
  const OrdersGateScreen({super.key});

  @override
  ConsumerState<OrdersGateScreen> createState() => _OrdersGateScreenState();
}

class _OrdersGateScreenState extends ConsumerState<OrdersGateScreen> {
  bool previous = false;

  bool _done(String status) =>
      const {'delivered', 'returned', 'rejected'}.contains(status);

  bool _needsReceipt(OrderModel order) {
    final method = order.paymentMethod.trim().toLowerCase();
    final status = order.paymentStatus.trim().toLowerCase();
    return method == 'transfer' &&
        !const {'receipt_pending', 'approved', 'paid'}.contains(status) &&
        !_done(order.status);
  }

  bool _receiptPending(OrderModel order) {
    final method = order.paymentMethod.trim().toLowerCase();
    final status = order.paymentStatus.trim().toLowerCase();
    return method == 'transfer' && status == 'receipt_pending';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(hasSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: session.when(
          loading: () => const SpikeLoading(),
          error: (_, __) => _LoginRequired(
            onLogin: () => context.push('/login?next=%2Forders'),
          ),
          data: (loggedIn) => loggedIn
              ? _orders(context)
              : _LoginRequired(
                  onLogin: () => context.push('/login?next=%2Forders'),
                ),
        ),
      ),
    );
  }

  Widget _orders(BuildContext context) {
    final state = ref.watch(ordersProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        _head(context, 'طلباتي'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SpikeSpacing.page,
            0,
            SpikeSpacing.page,
            18,
          ),
          child: Row(
            children: [
              _tab('الحالية', !previous, () => setState(() => previous = false), dark),
              const SizedBox(width: 9),
              _tab('السابقة', previous, () => setState(() => previous = true), dark),
            ],
          ),
        ),
        Expanded(
          child: state.when(
            loading: () => const SpikeLoading(),
            error: (error, _) => SpikeErrorState(
              message: _friendlyError(error),
              onRetry: () => ref.invalidate(ordersProvider),
            ),
            data: (orders) {
              final list = orders
                  .where((order) => previous ? _done(order.status) : !_done(order.status))
                  .toList();
              if (list.isEmpty) {
                return SpikeEmptyState(
                  message: previous
                      ? 'لا توجد طلبات سابقة حتى الآن'
                      : 'طلباتك الجديدة ستظهر هنا',
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(ordersProvider);
                  await ref.read(ordersProvider.future);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    SpikeSpacing.page,
                    0,
                    SpikeSpacing.page,
                    SpikeSpacing.xl,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 13),
                  itemBuilder: (context, index) => _OrderCard(
                    order: list[index],
                    dark: dark,
                    needsReceipt: _needsReceipt(list[index]),
                    receiptPending: _receiptPending(list[index]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _friendlyError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('unauthorized') || raw.contains('401')) {
      return 'انتهت جلسة تسجيل الدخول. سجّل الدخول مرة أخرى.';
    }
    return error.toString();
  }

  Widget _tab(String label, bool active, VoidCallback onTap, bool dark) =>
      SizedBox(
        width: 88,
        height: 39,
        child: FilledButton(
          style: FilledButton.styleFrom(
            elevation: 0,
            padding: EdgeInsets.zero,
            backgroundColor: active
                ? (dark ? Colors.white : Colors.black)
                : (dark ? spikeDarkPanel : const Color(0xFFE7E7E7)),
            foregroundColor: active
                ? (dark ? Colors.black : Colors.white)
                : Theme.of(context).colorScheme.onSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          onPressed: onTap,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      );
}

class OrderDetailsGateScreen extends ConsumerWidget {
  const OrderDetailsGateScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(hasSessionProvider);
    return session.when(
      loading: () => const Scaffold(body: SafeArea(child: SpikeLoading())),
      error: (_, __) => Scaffold(
        body: SafeArea(
          child: _LoginRequired(
            onLogin: () => context.push(
              '/login?next=${Uri.encodeComponent('/order/$id')}',
            ),
          ),
        ),
      ),
      data: (loggedIn) => loggedIn
          ? OrderDetailsScreen(id: id)
          : Scaffold(
              body: SafeArea(
                child: _LoginRequired(
                  onLogin: () => context.push(
                    '/login?next=${Uri.encodeComponent('/order/$id')}',
                  ),
                ),
              ),
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.dark,
    required this.needsReceipt,
    required this.receiptPending,
  });

  final OrderModel order;
  final bool dark;
  final bool needsReceipt;
  final bool receiptPending;

  @override
  Widget build(BuildContext context) {
    final split = order.spikeWalletAmount > 0 && order.remainingAmount > 0;
    return InkWell(
      onTap: () => context.push('/order/${order.id}'),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark ? spikeDarkPanel : const Color(0xFFE9E9E9),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusLabel(order.status),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (order.displayDate.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            order.displayDate,
                            style: const TextStyle(
                              fontSize: 9,
                              color: spikeMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '#${_short(order.id)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (needsReceipt) ...[
              const SizedBox(height: 10),
              _ReceiptBadge(
                color: spikeRed,
                icon: LucideIcons.receipt,
                text: 'سند الحوالة مطلوب',
              ),
              const SizedBox(height: 6),
              const Text(
                'ارفع سند الحوالة لإكمال مراجعة الدفع.',
                style: TextStyle(fontSize: 10, color: spikeRed),
              ),
            ] else if (receiptPending) ...[
              const SizedBox(height: 10),
              const _ReceiptBadge(
                color: Color(0xFFC47A00),
                icon: LucideIcons.clock3,
                text: 'السند قيد المراجعة',
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 11),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        split
                            ? 'محفظة سبايك + ${_paymentMethodLabel(order.paymentMethod)}'
                            : _paymentMethodLabel(order.paymentMethod),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _paymentStatusLabel(order.paymentStatus),
                        style: const TextStyle(fontSize: 9, color: spikeMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${order.total.toStringAsFixed(2)} ${order.currencyCode}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(LucideIcons.chevronLeft, size: 18, color: spikeMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _short(String id) => id.length <= 8 ? id : id.substring(0, 8);

  static String _statusLabel(String status) => switch (status) {
        'pending_admin_review' => 'قيد مراجعة الإدارة',
        'approved' => 'تم اعتماد الطلب',
        'accepted' => 'تم التأكيد',
        'processing' => 'قيد التجهيز',
        'ready_for_delivery' => 'جاهز للتوصيل',
        'assigned' => 'تم تعيين مكتب التوصيل',
        'picked_up' => 'تم الاستلام من المتجر',
        'with_courier' => 'مع المندوب',
        'delivered' => 'تم التوصيل',
        'returned' => 'مرتجع',
        'rejected' => 'مرفوض',
        _ => status,
      };

  static String _paymentMethodLabel(String method) => switch (method) {
        'transfer' => 'حوالة مالية',
        'cod' => 'الدفع عند الاستلام',
        'wallet' => 'محفظة إلكترونية',
        'spike_wallet' => 'محفظة سبايك',
        _ => method,
      };

  static String _paymentStatusLabel(String status) => switch (status) {
        'receipt_pending' => 'السند قيد المراجعة',
        'approved' => 'تم اعتماد الدفع',
        'paid' => 'تم دفع المبلغ',
        'pending_collection' => 'الدفع عند الاستلام',
        'cod_confirmed' => 'تم تأكيد الطلب',
        _ => status,
      };
}

class _ReceiptBadge extends StatelessWidget {
  const _ReceiptBadge({
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: .32)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                text,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
}

class _LoginRequired extends StatelessWidget {
  const _LoginRequired({required this.onLogin});
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.packageSearch, size: 44),
              const SizedBox(height: 14),
              const Text(
                'سجّل الدخول لعرض طلباتك',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              const Text(
                'تابع طلباتك الحالية والسابقة من حسابك.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: spikeMuted, height: 1.5),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 43,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: spikeRed),
                  onPressed: onLogin,
                  child: const Text(
                    'تسجيل الدخول',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
