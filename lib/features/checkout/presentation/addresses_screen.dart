import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import '../data/commerce_repository.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  void _goLogin(BuildContext context) => context.push('/login?next=${Uri.encodeComponent('/addresses')}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addressesProvider);
    final session = ref.watch(hasSessionProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark ? const Color(0xFF1D1D1D) : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _AddressHead(title: 'اختيار العنوان', onBack: () => context.canPop() ? context.pop() : context.go('/')),
          Expanded(
            child: session.when(
              loading: () => const SpikeLoading(),
              error: (e, _) => SpikeErrorState(message: e.toString(), onRetry: () => ref.invalidate(hasSessionProvider)),
              data: (loggedIn) => !loggedIn
                  ? _LoginRequired(onLogin: () => _goLogin(context))
                  : state.when(
                      loading: () => const SpikeLoading(),
                      error: (e, _) => e is ApiException && e.statusCode == 401
                          ? _LoginRequired(expired: true, onLogin: () => _goLogin(context))
                          : SpikeErrorState(message: e.toString(), onRetry: () => ref.invalidate(addressesProvider)),
                      data: (items) => RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(addressesProvider);
                          await ref.read(addressesProvider.future);
                        },
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(17, 10, 17, 24),
                          children: [
                            const Text('اختر عنوان التوصيل النشط أو عدّل أحد العناوين المحفوظة.', style: TextStyle(fontSize: 12, color: spikeMuted)),
                            const SizedBox(height: 14),
                            if (items.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 38),
                                child: Column(children: [
                                  Icon(LucideIcons.mapPin, size: 38, color: spikeMuted),
                                  SizedBox(height: 12),
                                  Text('لا توجد عناوين محفوظة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                  SizedBox(height: 6),
                                  Text('أضف عنوان التوصيل حتى تتمكن من إكمال الطلب.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: spikeMuted)),
                                ]),
                              ),
                            for (final a in items) ...[
                              Container(
                                decoration: BoxDecoration(
                                  color: card,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: a.isActive ? Theme.of(context).colorScheme.onSurface : Theme.of(context).dividerColor),
                                ),
                                child: Row(children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        try {
                                          await ref.read(commerceRepositoryProvider).activateAddress(a.id);
                                          ref.invalidate(addressesProvider);
                                          if (context.mounted) {
                                            showSpikeToast(context, 'تم اختيار العنوان');
                                            context.pop(a.id);
                                          }
                                        } catch (_) {
                                          if (context.mounted) showSpikeToast(context, 'تعذر اختيار العنوان، حاول مرة أخرى');
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(18),
                                      child: Container(
                                        constraints: const BoxConstraints(minHeight: 74),
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Row(children: [
                                          const SizedBox(width: 28, child: Icon(LucideIcons.mapPin, size: 19)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              Text(a.addressLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                              const SizedBox(height: 4),
                                              Text('${a.recipientName} • ${a.phone}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: spikeMuted)),
                                            ]),
                                          ),
                                          SizedBox(width: 25, child: a.isActive ? const Icon(Icons.check, size: 18) : null),
                                        ]),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await context.push('/address-form', extra: a);
                                      ref.invalidate(addressesProvider);
                                    },
                                    child: const Text('تعديل', style: TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
                                  ),
                                ]),
                              ),
                              const SizedBox(height: 10),
                            ],
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 50,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.onSurface, foregroundColor: Theme.of(context).colorScheme.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                onPressed: () async {
                                  await context.push('/address-form');
                                  ref.invalidate(addressesProvider);
                                },
                                icon: const Icon(LucideIcons.plus, size: 18),
                                label: const Text('إضافة عنوان جديد', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}

class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.address});
  final AddressModel? address;
  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  late final TextEditingController line;
  late final TextEditingController maps;
  String? cityId;
  String label = 'المنزل';
  bool active = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    line = TextEditingController(text: a?.addressLine ?? '');
    maps = TextEditingController(text: a?.googleMapsUrl ?? '');
    cityId = a?.cityId;
    label = a?.label.isNotEmpty == true ? a!.label : 'المنزل';
    active = a?.isActive ?? true;
  }

  @override
  void dispose() {
    line.dispose();
    maps.dispose();
    super.dispose();
  }

  String get _typeKey => label == 'مكتب' ? 'office' : label == 'أخرى' ? 'other' : 'home';

  void _setType(String type) => setState(() => label = type == 'office' ? 'مكتب' : type == 'other' ? 'أخرى' : 'المنزل');

  Future<void> _delete() async {
    final a = widget.address;
    if (a == null || busy) return;
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('حذف العنوان'),
            content: const Text('هل تريد حذف هذا العنوان؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318)), onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    setState(() => busy = true);
    try {
      await ref.read(commerceRepositoryProvider).deleteAddress(a.id);
      ref.invalidate(addressesProvider);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) showSpikeToast(context, 'تعذر حذف العنوان، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy) return;
    final user = await ref.read(currentUserProvider.future);
    final recipientName = '${user?['name'] ?? ''}'.trim();
    final recipientPhone = '${user?['phone'] ?? ''}'.trim();
    if (recipientName.isEmpty || recipientPhone.isEmpty) {
      if (mounted) showSpikeToast(context, 'أكمل الاسم ورقم الجوال في البيانات الشخصية أولاً');
      return;
    }
    if (cityId == null || line.text.trim().isEmpty) {
      if (mounted) showSpikeToast(context, 'أكمل العنوان ومدينة التغطية');
      return;
    }
    setState(() => busy = true);
    try {
      final repository = ref.read(commerceRepositoryProvider);
      if (widget.address == null) {
        final existing = await repository.addresses();
        await repository.createAddress(
          cityId: cityId!,
          label: label,
          recipientName: recipientName,
          phone: recipientPhone,
          addressLine: line.text.trim(),
          googleMapsUrl: maps.text.trim(),
          isActive: existing.isEmpty ? true : active,
        );
      } else {
        await repository.updateAddress(
          widget.address!.id,
          cityId: cityId!,
          label: label,
          recipientName: recipientName,
          phone: recipientPhone,
          addressLine: line.text.trim(),
          googleMapsUrl: maps.text.trim(),
          isActive: active,
        );
      }
      ref.invalidate(addressesProvider);
      if (mounted) {
        showSpikeToast(context, 'تم حفظ العنوان');
        context.pop();
      }
    } catch (_) {
      if (mounted) showSpikeToast(context, 'تعذر حفظ العنوان، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cities = ref.watch(citiesProvider);
    final personal = ref.watch(currentUserProvider);
    final personalUser = personal.valueOrNull;
    final personalName = '${personalUser?['name'] ?? ''}'.trim();
    final personalPhone = '${personalUser?['phone'] ?? ''}'.trim();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark ? const Color(0xFF1D1D1D) : Colors.white;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _AddressHead(
            title: widget.address == null ? 'إضافة عنوان جديد' : 'تعديل العنوان',
            onBack: () => context.canPop() ? context.pop() : context.go('/'),
            action: widget.address == null ? null : IconButton(onPressed: busy ? null : _delete, icon: const Icon(LucideIcons.trash2, size: 21, color: Color(0xFFB42318))),
          ),
          Expanded(
            child: cities.when(
              loading: () => const SpikeLoading(),
              error: (e, _) => SpikeErrorState(message: e.toString(), onRetry: () => ref.invalidate(citiesProvider)),
              data: (list) => ListView(
                padding: const EdgeInsets.fromLTRB(17, 0, 17, 20),
                children: [
                  const Text('تفاصيل العنوان', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _ReferenceField(controller: line, icon: LucideIcons.house, hint: 'العنوان *'),
                  const SizedBox(height: 12),
                  _ReferenceField(controller: maps, icon: LucideIcons.mapPin, hint: 'رابط Google Maps (اختياري)', keyboard: TextInputType.url, ltr: true),
                  const SizedBox(height: 7),
                  const Text('Google Maps اختياري ويساعد على حساب التوصيل بدقة أكبر.', style: TextStyle(fontSize: 10, color: spikeMuted, height: 1.45)),
                  const SizedBox(height: 12),
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: card, border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(15)),
                    child: Row(children: [
                      const SizedBox(width: 30, child: Icon(LucideIcons.map, size: 19, color: spikeMuted)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: cityId,
                            isExpanded: true,
                            hint: Text('مدينة التغطية *', style: spikeTextStyle(fontSize: 13, color: spikeMuted)),
                            items: list.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: spikeTextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) => setState(() => cityId = v),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  const Text('المستلم', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _ProfileContact(icon: LucideIcons.user, label: 'اسم المستلم', value: personalName.isEmpty ? 'أكمل الاسم من البيانات الشخصية' : personalName),
                  const SizedBox(height: 12),
                  _ProfileContact(icon: LucideIcons.phone, label: 'رقم الجوال', value: personalPhone.isEmpty ? 'أكمل رقم الجوال من البيانات الشخصية' : personalPhone, ltr: true),
                  const SizedBox(height: 7),
                  const Text('اسم المستلم ورقم الجوال مرتبطان ببياناتك الشخصية ولا يتم تعديلهما من العنوان.', style: TextStyle(fontSize: 10, color: spikeMuted, height: 1.45)),
                  const SizedBox(height: 20),
                  const Text('حفظ العنوان باسم', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _AddressType(type: 'home', title: 'المنزل', icon: LucideIcons.house, selected: _typeKey == 'home', onTap: _setType)),
                    const SizedBox(width: 9),
                    Expanded(child: _AddressType(type: 'office', title: 'مكتب', icon: LucideIcons.building2, selected: _typeKey == 'office', onTap: _setType)),
                    const SizedBox(width: 9),
                    Expanded(child: _AddressType(type: 'other', title: 'أخرى', icon: LucideIcons.mapPinned, selected: _typeKey == 'other', onTap: _setType)),
                  ]),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => setState(() => active = !active),
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(17)),
                      child: Row(children: [
                        Container(width: 29, height: 29, decoration: BoxDecoration(color: const Color(0xFFFFF6DF), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.check, size: 17, color: Color(0xFFF0AD14))),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('تعيين كعنوان التوصيل الافتراضي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                        Switch(value: active, onChanged: (v) => setState(() => active = v)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(height: 48, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: spikeYellow, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: busy ? null : save, child: busy ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('حفظ العنوان', style: TextStyle(fontWeight: FontWeight.w700)))),
                  const SizedBox(height: 10),
                  SizedBox(height: 48, child: OutlinedButton(onPressed: busy ? null : () => context.pop(), child: const Text('إلغاء')),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _AddressHead extends StatelessWidget {
  const _AddressHead({required this.title, required this.onBack, this.action});
  final String title;
  final VoidCallback onBack;
  final Widget? action;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17),
          child: Stack(alignment: Alignment.center, children: [
            Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            Align(alignment: Alignment.centerRight, child: SizedBox(width: 50, height: 40, child: Material(color: Theme.of(context).brightness == Brightness.dark ? spikeDarkPanel : const Color(0xFFE8E8E8), borderRadius: BorderRadius.circular(22), child: InkWell(borderRadius: BorderRadius.circular(22), onTap: onBack, child: const Icon(LucideIcons.arrowRight, size: 23))))),
            if (action != null) Align(alignment: Alignment.centerLeft, child: action!),
          ]),
        ),
      );
}

class _ReferenceField extends StatelessWidget {
  const _ReferenceField({required this.controller, required this.icon, required this.hint, this.keyboard, this.ltr = false, this.height = 54});
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final TextInputType? keyboard;
  final bool ltr;
  final double height;
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1D1D1D) : Colors.white, border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(15)),
        child: TextField(
          controller: controller,
          keyboardType: keyboard,
          textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
          style: spikeTextStyle(fontSize: 13),
          decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: spikeTextStyle(fontSize: 13, color: spikeMuted), prefixIcon: Icon(icon, size: 19, color: spikeMuted), contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12)),
        ),
      );
}

class _ProfileContact extends StatelessWidget {
  const _ProfileContact({required this.icon, required this.label, required this.value, this.ltr = false});
  final IconData icon;
  final String label, value;
  final bool ltr;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1D1D1D) : Colors.white,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(children: [
          Icon(icon, size: 19, color: spikeMuted),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 9, color: spikeMuted)),
            const SizedBox(height: 2),
            Text(value, textDirection: ltr ? TextDirection.ltr : TextDirection.rtl, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ])),
          const Icon(LucideIcons.lock, size: 15, color: spikeMuted),
        ]),
      );
}

class _AddressType extends StatelessWidget {
  const _AddressType({required this.type, required this.title, required this.icon, required this.selected, required this.onTap});
  final String type, title;
  final IconData icon;
  final bool selected;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onTap(type),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 83,
          decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1D1D1D) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).dividerColor)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 22), const SizedBox(height: 7), Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))]),
        ),
      );
}

class _LoginRequired extends StatelessWidget {
  const _LoginRequired({required this.onLogin, this.expired = false});
  final VoidCallback onLogin;
  final bool expired;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.lock, size: 36, color: spikeMuted),
            const SizedBox(height: 12),
            Text(expired ? 'انتهت الجلسة' : 'تسجيل الدخول مطلوب', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            Text(expired ? 'سجّل الدخول مرة أخرى للوصول إلى عناوينك.' : 'سجّل الدخول لإدارة عناوين التوصيل.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: spikeMuted)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onLogin, child: const Text('تسجيل الدخول')),
          ]),
        ),
      );
}
