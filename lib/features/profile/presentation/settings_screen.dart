import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import '../../checkout/data/commerce_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final ctrl = ref.read(appSettingsProvider.notifier);
    final currencies = ref.watch(currenciesProvider);
    final session = ref.watch(hasSessionProvider).valueOrNull ?? false;
    final ar = settings.language == 'ar';

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 8, 17, 4),
            child: SizedBox(
              height: 52,
              child: Stack(alignment: Alignment.center, children: [
                Text(ar ? 'الإعدادات المتقدمة' : 'Advanced settings', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(onPressed: () => context.canPop() ? context.pop() : context.go('/profile'), icon: const Icon(LucideIcons.arrowRight, size: 22)),
                ),
              ]),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(17, 8, 17, 28),
              children: [
                _SettingsSection(
                  icon: LucideIcons.sunMoon,
                  title: ar ? 'المظهر' : 'Appearance',
                  subtitle: ar ? 'اختر الوضع المناسب لك' : 'Choose your preferred appearance',
                  child: Row(children: [
                    Expanded(child: _ThemeOption(title: ar ? 'الوضع الفاتح' : 'Light mode', selected: settings.themeMode == ThemeMode.light, darkPreview: false, onTap: () => ctrl.setTheme(ThemeMode.light))),
                    const SizedBox(width: 9),
                    Expanded(child: _ThemeOption(title: ar ? 'الوضع الداكن' : 'Dark mode', selected: settings.themeMode == ThemeMode.dark, darkPreview: true, onTap: () => ctrl.setTheme(ThemeMode.dark))),
                  ]),
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  icon: LucideIcons.languages,
                  title: ar ? 'اللغة' : 'Language',
                  subtitle: ar ? 'لغة واجهة التطبيق' : 'App interface language',
                  child: Row(children: [
                    Expanded(child: _ChoiceCard(title: 'العربية', subtitle: 'Arabic', selected: settings.language == 'ar', onTap: () => ctrl.setLanguage('ar'))),
                    const SizedBox(width: 9),
                    Expanded(child: _ChoiceCard(title: 'English', subtitle: 'الإنجليزية', selected: settings.language == 'en', onTap: () => ctrl.setLanguage('en'))),
                  ]),
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  icon: LucideIcons.coins,
                  title: ar ? 'العملة' : 'Currency',
                  subtitle: ar ? 'اختر العملة التي تريد عرض الأسعار بها' : 'Choose the currency used to display prices',
                  child: currencies.when(
                    loading: () => const Padding(padding: EdgeInsets.all(12), child: SpikeLoading()),
                    error: (e, _) => SpikeErrorState(message: e.toString(), onRetry: () => ref.invalidate(currenciesProvider)),
                    data: (items) {
                      final selected = items.where((c) => c.code == settings.currency).firstOrNull;
                      return InkWell(
                        onTap: items.isEmpty ? null : () => _showCurrencySheet(context, items, settings.currency, ctrl),
                        borderRadius: BorderRadius.circular(17),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 58),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF282828) : Colors.white,
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(selected?.name ?? (ar ? 'لا توجد عملة متاحة' : 'No currency available'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Text(selected?.code ?? '', style: const TextStyle(fontSize: 9, color: spikeMuted)),
                              ]),
                            ),
                            const Icon(LucideIcons.chevronDown, size: 18),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? spikeDarkPanel : spikePanel,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(ar ? 'حذف الحساب' : 'Delete account', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Text(
                      ar ? 'سيتم تعطيل الحساب وإخفاء بياناته الشخصية بعد التأكيد مع الاحتفاظ بسجلات الطلبات والعمليات المطلوبة قانونياً.' : 'Your account will be disabled and personal profile data hidden after confirmation.',
                      style: const TextStyle(fontSize: 9.5, color: spikeMuted, height: 1.55),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: spikeRed, side: const BorderSide(color: spikeRed), minimumSize: const Size.fromHeight(42), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
                      onPressed: () {
                        if (!session) {
                          showSpikeToast(context, ar ? 'سجّل الدخول أولاً لحذف الحساب' : 'Sign in first to delete your account');
                          context.push('/login?next=${Uri.encodeComponent('/settings')}');
                          return;
                        }
                        context.push('/delete-account');
                      },
                      child: Text(ar ? 'حذف الحساب' : 'Delete account'),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 43,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
                    onPressed: () => showSpikeToast(context, ar ? 'تم حفظ التعديلات' : 'Changes saved'),
                    child: Text(ar ? 'حفظ التعديلات' : 'Save changes', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _showCurrencySheet(BuildContext context, List<CurrencyModel> items, String current, AppSettingsController ctrl) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 4, 17, 22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Expanded(child: Text('اختر العملة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(LucideIcons.x, size: 20)),
            ]),
            const SizedBox(height: 8),
            for (final item in items) ...[
              InkWell(
                onTap: () async {
                  await ctrl.setCurrency(item.code);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                borderRadius: BorderRadius.circular(17),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 58),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: current == item.code ? Theme.of(context).colorScheme.onSurface : Theme.of(context).dividerColor),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text(item.code, style: const TextStyle(fontSize: 8, color: spikeMuted))])),
                    _RadioDot(selected: current == item.code),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ]),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.icon, required this.title, required this.subtitle, required this.child});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final panel = dark ? spikeDarkPanel : spikePanel;
    final inner = dark ? const Color(0xFF282828) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: inner, borderRadius: BorderRadius.circular(14)), child: Icon(icon, size: 18)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.25)),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(fontSize: 9, color: spikeMuted, height: 1.55)),
          ])),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({required this.title, required this.selected, required this.darkPreview, required this.onTap});
  final String title;
  final bool selected;
  final bool darkPreview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inner = dark ? const Color(0xFF282828) : Colors.white;
    final border = selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: inner, borderRadius: BorderRadius.circular(18), border: Border.all(color: border)),
        child: Column(children: [
          Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))), _RadioDot(selected: selected)]),
          const SizedBox(height: 8),
          Container(
            height: 66,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: darkPreview ? const Color(0xFF151515) : const Color(0xFFF3F3F3), borderRadius: BorderRadius.circular(13)),
            child: Column(children: [
              Container(height: 12, decoration: BoxDecoration(color: darkPreview ? const Color(0xFF303030) : Colors.white, borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 6),
              Expanded(child: Row(children: [
                Expanded(child: Container(decoration: BoxDecoration(color: darkPreview ? const Color(0xFF303030) : Colors.white, borderRadius: BorderRadius.circular(6)))),
                const SizedBox(width: 6),
                Expanded(child: Container(decoration: BoxDecoration(color: darkPreview ? const Color(0xFF303030) : Colors.white, borderRadius: BorderRadius.circular(6)))),
              ])),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.title, required this.subtitle, required this.selected, required this.onTap});
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inner = dark ? const Color(0xFF282828) : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(color: inner, borderRadius: BorderRadius.circular(17), border: Border.all(color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent)),
        child: Row(children: [
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 8, color: spikeMuted)),
          ])),
          _RadioDot(selected: selected),
        ]),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: 17,
      height: 17,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? color : spikeMuted, width: 1.5)),
      child: selected ? DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: color)) : null,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
