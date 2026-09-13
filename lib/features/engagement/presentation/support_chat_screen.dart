import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';

class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});
  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  final text = TextEditingController();
  final scroll = ScrollController();
  String? threadId;
  List<Map<String, dynamic>> messages = [];
  bool loading = true, sending = false;
  Map<String, dynamic> service = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _bottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  bool _unauthorized(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('unauthorized') || raw.contains('401');
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      final repo = ref.read(engagementRepositoryProvider);
      service = await repo.publicSettings();
      final loggedIn = await ref.read(hasSessionProvider.future);
      if (!loggedIn) {
        threadId = null;
        messages = const [];
        return;
      }
      threadId = await repo.ensureSupportThread();
      messages = await repo.supportMessages(threadId!);
      _bottom();
    } catch (e) {
      if (_unauthorized(e)) {
        ref.invalidate(hasSessionProvider);
        ref.invalidate(currentUserProvider);
        threadId = null;
        messages = const [];
      } else if (mounted) {
        showSpikeToast(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openService(String scheme, String value) async {
    final cleaned = scheme == 'tel' ? value.replaceAll(RegExp(r'\s+'), '') : value.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse(scheme == 'tel' ? 'tel:$cleaned' : 'https://wa.me/$cleaned');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      showSpikeToast(context, 'تعذر فتح وسيلة التواصل');
    }
  }

  Future<void> _send() async {
    final body = text.text.trim();
    if (body.isEmpty || threadId == null || sending) return;
    setState(() => sending = true);
    try {
      final repo = ref.read(engagementRepositoryProvider);
      await repo.sendSupportMessage(threadId!, body);
      text.clear();
      messages = await repo.supportMessages(threadId!);
      if (mounted) setState(() {});
      _bottom();
    } catch (e) {
      if (_unauthorized(e)) {
        ref.invalidate(hasSessionProvider);
        ref.invalidate(currentUserProvider);
        threadId = null;
        messages = const [];
        if (mounted) setState(() {});
      } else if (mounted) {
        showSpikeToast(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(hasSessionProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: session.when(
          loading: () => const SpikeLoading(),
          error: (_, __) => _loginRequired(context),
          data: (loggedIn) => loggedIn ? _supportBody(dark, scheme) : _loginRequired(context),
        ),
      ),
    );
  }

  Widget _loginRequired(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(SpikeSpacing.page, SpikeSpacing.sm, SpikeSpacing.page, 0),
            child: SizedBox(
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text('خدمة العملاء', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
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
                        child: const Text('تسجيل الدخول', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  Widget _supportBody(bool dark, ColorScheme scheme) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(SpikeSpacing.page, SpikeSpacing.sm, SpikeSpacing.page, 0),
          child: SizedBox(height: 60, child: Stack(alignment: Alignment.center, children: [
            const Text('خدمة العملاء', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            Align(alignment: Alignment.centerRight, child: IconButton(onPressed: () => context.canPop() ? context.pop() : context.go('/profile'), icon: const Icon(LucideIcons.arrowRight, size: 22))),
            Align(alignment: Alignment.centerLeft, child: IconButton(onPressed: _load, icon: const Icon(LucideIcons.refreshCw, size: 18))),
          ])),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(SpikeSpacing.page, 0, SpikeSpacing.page, 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: dark ? spikeDarkPanel : Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: scheme.onSurface.withValues(alpha: .08))),
            child: Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: spikeRed.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)), child: const Icon(LucideIcons.shieldCheck, size: 21, color: spikeRed)),
              const SizedBox(width: 10),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('إدارة Spike', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)), SizedBox(height: 2), Text('الدعم والمساعدة', style: TextStyle(fontSize: 10, color: spikeMuted))])),
              Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 0, 17, 10),
          child: Row(children: [
            Expanded(child: _ServiceButton(icon: LucideIcons.phone, label: 'اتصال', value: '${service['customer_service_phone'] ?? ''}', onTap: () => _openService('tel', '${service['customer_service_phone'] ?? ''}'))),
            const SizedBox(width: 8),
            Expanded(child: _ServiceButton(icon: LucideIcons.messageCircle, label: 'واتساب', value: '${service['customer_service_whatsapp'] ?? ''}', onTap: () => _openService('wa', '${service['customer_service_whatsapp'] ?? ''}'))),
          ]),
        ),
        Expanded(
          child: loading
              ? const SpikeLoading()
              : messages.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 34), child: Column(mainAxisSize: MainAxisSize.min, children: [Text('مرحباً 👋', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), SizedBox(height: 8), Text('اكتب رسالتك للإدارة وسيظهر الرد هنا في نفس المحادثة.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, height: 1.6, color: spikeMuted))])))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(SpikeSpacing.page, 8, SpikeSpacing.page, 18),
                        itemCount: messages.length,
                        itemBuilder: (context, i) {
                          final m = messages[i];
                          final mine = '${m['sender_role'] ?? ''}' == 'customer';
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 286),
                              margin: const EdgeInsets.only(bottom: 9),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: mine ? spikeRed : (dark ? spikeDarkPanel : const Color(0xFFE9E9E9)),
                                borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(mine ? 18 : 5), bottomRight: Radius.circular(mine ? 5 : 18)),
                              ),
                              child: Text('${m['body'] ?? ''}', style: TextStyle(fontSize: 12, height: 1.5, color: mine ? Colors.white : null)),
                            ),
                          );
                        },
                      ),
                    ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(SpikeSpacing.page, 8, SpikeSpacing.page, 8),
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, border: Border(top: BorderSide(color: scheme.onSurface.withValues(alpha: .08)))),
          child: SafeArea(
            top: false,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: text,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(hintText: 'اكتب رسالة...', filled: true, fillColor: dark ? spikeDarkPanel : const Color(0xFFE7E7E7), border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(22)), enabledBorder: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(22)), focusedBorder: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(22))),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 44, height: 44, child: IconButton.filled(style: IconButton.styleFrom(backgroundColor: spikeRed), onPressed: sending ? null : _send, icon: sending ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(LucideIcons.send, color: Colors.white, size: 19))),
            ]),
          ),
        ),
      ]);
}

class _ServiceButton extends StatelessWidget {
  const _ServiceButton({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon; final String label; final String value; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final enabled = value.trim().isNotEmpty;
    return OutlinedButton.icon(onPressed: enabled ? onTap : null, icon: Icon(icon, size: 17), label: Text(enabled ? label : '$label غير متاح', style: const TextStyle(fontSize: 10)), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 39)));
  }
}
