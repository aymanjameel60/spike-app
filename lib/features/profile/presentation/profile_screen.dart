import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/providers.dart';
import '../../../core/api_config.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import '../../../core/widgets/spike_network_image.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final shareWin = ref.watch(shareWinPublicProvider);

    return SafeArea(
      child: user.when(
        loading: () => const SpikeLoading(),
        error: (error, _) => SpikeErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
        data: (u) {
          final current = u ?? <String, dynamic>{};
          final raw = '${current['avatar_url'] ?? current['avatarUrl'] ?? ''}';
          final avatar = ApiConfig.resolveMedia(raw);
          final name = '${current['name'] ?? ''}';
          final phone = '${current['phone'] ?? ''}';
          final rawEmail = '${current['email'] ?? ''}';
          final email = rawEmail.endsWith('@customer.spike.local') ? '' : rawEmail;
          final shareConfig = shareWin.valueOrNull;
          final shareEnabled = shareConfig?['enabled'] == true;
          final dark = Theme.of(context).brightness == Brightness.dark;

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Row(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 70,
                        height: 70,
                        child: avatar.isEmpty
                            ? ColoredBox(
                                color: dark ? spikeDarkPanel : spikePanel,
                                child: const Center(
                                  child: Icon(LucideIcons.userRound, size: 31),
                                ),
                              )
                            : SpikeNetworkImage(
                                url: avatar,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: name.isEmpty
                          ? const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'مرحباً بك في Spike',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'سجّل الدخول لمتابعة طلباتك وبياناتك',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: spikeMuted,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'مرحباً $name',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (phone.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    phone,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: spikeMuted,
                                    ),
                                  ),
                                ],
                                if (email.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: spikeMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Column(
                  children: [
                    _row(
                      context,
                      LucideIcons.userRound,
                      'البيانات الشخصية',
                      () => context.push('/personal-data'),
                    ),
                    const SizedBox(height: 16),
                    _row(
                      context,
                      LucideIcons.store,
                      'المتاجر',
                      () => context.push('/stores'),
                    ),
                    if (shareEnabled) ...[
                      const SizedBox(height: 16),
                      _row(
                        context,
                        LucideIcons.gift,
                        '${shareConfig?['headline'] ?? 'شارك واربح'}',
                        () => u == null
                            ? context.push(
                                '/login?next=${Uri.encodeComponent('/share-win')}',
                              )
                            : context.push('/share-win'),
                        featured: true,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _row(
                      context,
                      LucideIcons.walletCards,
                      'محفظتي',
                      () => u == null
                          ? context.push(
                              '/login?next=${Uri.encodeComponent('/wallet')}',
                            )
                          : context.push('/wallet'),
                    ),
                    const SizedBox(height: 16),
                    _row(
                      context,
                      LucideIcons.heart,
                      'المفضلة',
                      () => context.push('/favorites'),
                    ),
                    const SizedBox(height: 16),
                    _row(
                      context,
                      LucideIcons.packageCheck,
                      'طلباتي',
                      () => context.push('/orders'),
                    ),
                    const SizedBox(height: 16),
                    _row(
                      context,
                      LucideIcons.messagesSquare,
                      'خدمة العملاء',
                      () => context.push('/support'),
                    ),
                    const SizedBox(height: 16),
                    _row(
                      context,
                      LucideIcons.shieldCheck,
                      'سياسة الخصوصية',
                      () => context.push('/privacy'),
                    ),
                    const SizedBox(height: 16),
                    _row(
                      context,
                      LucideIcons.settings2,
                      'الإعدادات المتقدمة',
                      () => context.push('/settings'),
                    ),
                    const SizedBox(height: 16),
                    _row(
                      context,
                      LucideIcons.store,
                      'سجّل كتاجر',
                      () => context.push('/vendor-registration'),
                      featured: true,
                    ),
                    const SizedBox(height: 16),
                    _row(
                      context,
                      u == null ? LucideIcons.logIn : LucideIcons.logOut,
                      u == null ? 'تسجيل الدخول' : 'تسجيل الخروج',
                      () async {
                        if (u == null) {
                          context.push('/login');
                          return;
                        }
                        await ref.read(authRepositoryProvider).logout();
                        ref.invalidate(currentUserProvider);
                        ref.invalidate(hasSessionProvider);
                        ref.invalidate(shareWinMeProvider);
                        ref.invalidate(shareWinPublicProvider);
                        if (context.mounted) context.go('/profile');
                      },
                      danger: u != null,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
    bool featured = false,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: featured
          ? (dark ? const Color(0xFF311619) : const Color(0xFFFFF1F2))
          : (dark ? spikeDarkPanel : spikePanel),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 43,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: danger
                      ? spikeRed
                      : Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: danger ? spikeRed : null,
                      height: 1.25,
                    ),
                  ),
                ),
                if (featured)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: spikeRed,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'جديد',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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
