import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import 'support_chat_screen.dart';

class SupportGateScreen extends ConsumerWidget {
  const SupportGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(hasSessionProvider);
    return session.when(
      loading: () => const Scaffold(body: SafeArea(child: SpikeLoading())),
      error: (_, __) => _loginRequired(context),
      data: (loggedIn) => loggedIn ? const SupportChatScreen() : _loginRequired(context),
    );
  }

  Widget _loginRequired(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(SpikeSpacing.page, SpikeSpacing.sm, SpikeSpacing.page, 0),
                child: SizedBox(
                  height: 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Text(
                        'خدمة العملاء',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
                          icon: const Icon(LucideIcons.arrowRight, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 34),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.messageCircle, size: 44),
                        const SizedBox(height: 14),
                        const Text(
                          'سجّل الدخول لبدء المحادثة',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'تواصل مع إدارة Spike وتابع الردود من نفس حسابك.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: spikeMuted, height: 1.5),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 43,
                          child: FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: spikeRed),
                            onPressed: () => context.push('/login?next=%2Fsupport'),
                            child: const Text(
                              'تسجيل الدخول',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
