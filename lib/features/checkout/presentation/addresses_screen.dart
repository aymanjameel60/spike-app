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

  void _goLogin(BuildContext context) =>
      context.push('/login?next=${Uri.encodeComponent('/addresses')}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addressesProvider);
    final session = ref.watch(hasSessionProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark ? const Color(0xFF1D1D1D) : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _AddressHead(
              title: 'اختيار العنوان',
              onBack: () => context.canPop() ? context.pop() : context.go('/')),
          Expanded(
            child: session.when(
              loading: () => const SpikeLoading(),
              error: (e, _) => SpikeErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(hasSessionProvider)),
              data: (loggedIn) => !loggedIn
                  ? _LoginRequired(onLogin: () => _goLogin(context))
                  : state.when(
                      loading: () => const SpikeLoading(),
                      error: (e, _) => e is ApiException && e.statusCode == 401
                          ? _LoginRequired(
                              expired: true, onLogin: () => _goLogin(context))
                          : SpikeErrorState(
                              message: e.toString(),
                              onRetry: () => ref.invalidate(addressesProvider)),
                      data: (items) => RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(addressesProvider);
                          await ref.read(addressesProvider.future);
                        },
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(17, 10, 17, 24),
                          children: [
                            const Text(
                                'اختر عنوان التوصيل النشط أو عدّل أحد العناوين المحفوظة.',
                                style:
                                    TextStyle(fontSize: 12, color: spikeMuted)),
                            const SizedBox(height: 14),
                            if (items.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 50),
                                child: Text(
                                    'لا يوجد عنوان محفوظ بعد. أضف عنوان التوصيل الأول.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 11, color: spikeMuted)),
                              ),
                            for (final a in items) ...[
                              Container(
                                decoration: BoxDecoration(
                                  color: card,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: a.isActive
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                          : Theme.of(context).dividerColor),
                                ),
                                child: Row(children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        await ref
                                            .read(commerceRepositoryProvider)
                                            .activateAddress(a.id);
                                        ref.invalidate(addressesProvider);
                                        if (context.mounted) {
                                          showSpikeToast(
                                              context, 'تم اختيار العنوان');
                                          context.pop(a.id);
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(18),
                                      child: Container(
                                        constraints:
                                            const BoxConstraints(minHeight: 70),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        child: Row(children: [
                                          const SizedBox(
                                              width: 28,
                                              child: Icon(LucideIcons.mapPin,
                                                  size: 19)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                      '${a.label.isEmpty ? 'عنوان التوصيل' : a.label} - ${a.cityName}',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700)),
                                                  const SizedBox(height: 4),
                                                  Text(a.addressLine,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 10,
                                                          color: spikeMuted)),
                                                ]),
                                          ),
                                          SizedBox(
                                              width: 25,
                                              child: a.isActive
                                                  ? const Icon(Icons.check,
                                                      size: 18)
                                                  : null),
                                        ]),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                      onPressed: () => context
                                          .push('/address-form', extra: a),
                                      child: const Text('تعديل',
                                          style: TextStyle(
                                              fontSize: 12,
                                              decoration:
                                                  TextDecoration.underline))),
                                ]),
                              ),
                              const SizedBox(height: 10),
                            ],
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 50,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.onSurface,
                                  foregroundColor:
                                      Theme.of(context).colorScheme.surface,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () => context.push('/address-form'),
                                icon: const Icon(LucideIcons.plus, size: 18),
                                label: const Text('إضافة عنوان جديد',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
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
  late final TextEditingController name;
  late final TextEditingController phone;
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
    name = TextEditingController(text: a?.recipientName ?? '');
    phone = TextEditingController(text: a?.phone ?? '');
    line = TextEditingController(text: a?.addressLine ?? '');
    maps = TextEditingController(text: a?.googleMapsUrl ?? '');
    cityId = a?.cityId;
    label = a?.label.isNotEmpty == true ? a!.label : 'المنزل';
    active = a?.isActive ?? true;
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    line.dispose();
    maps.dispose();
    super.dispose();
  }

  String get _typeKey {
    if (label == 'مكتب') return 'office';
    if (label == 'أخرى') return 'other';
    return 'home';
  }

  void _setType(String type) {
    setState(() {
      label = type == 'office'
          ? 'مكتب'
          : type == 'other'
              ? 'أخرى'
              : 'المنزل';
    });
  }

  Future<void> save() async {
    if (busy) return;
    if (cityId == null ||
        name.text.trim().isEmpty ||
        phone.text.trim().isEmpty ||
        line.text.trim().isEmpty ||
        maps.text.trim().isEmpty) {
      showSpikeToast(context, 'أكمل جميع الحقول المطلوبة');
      return;
    }
    setState(() => busy = true);
    try {
      final repository = ref.read(commerceRepositoryProvider);
      if (widget.address == null) {
        await repository.createAddress(
          cityId: cityId!,
          label: label,
          recipientName: name.text,
          phone: phone.text,
          addressLine: line.text,
          googleMapsUrl: maps.text,
          isActive: active,
        );
      } else {
        await repository.updateAddress(
          widget.address!.id,
          cityId: cityId!,
          label: label,
          recipientName: name.text,
          phone: phone.text,
          addressLine: line.text,
          googleMapsUrl: maps.text,
          isActive: active,
        );
      }
      ref.invalidate(addressesProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cities = ref.watch(citiesProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark ? const Color(0xFF1D1D1D) : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _AddressHead(
              title:
                  widget.address == null ? 'إضافة عنوان جديد' : 'تعديل العنوان',
              onBack: () => context.canPop() ? context.pop() : context.go('/')),
          Expanded(
            child: cities.when(
              loading: () => const SpikeLoading(),
              error: (e, _) => SpikeErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(citiesProvider)),
              data: (list) => ListView(
                padding: const EdgeInsets.fromLTRB(17, 0, 17, 20),
                children: [
                  const Text('تفاصيل العنوان',
                      style:
                          TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _ReferenceField(
                      controller: line,
                      icon: LucideIcons.house,
                      hint: 'العنوان بالتفصيل *'),
                  const SizedBox(height: 12),
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                        color: card,
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(15)),
                    child: Row(children: [
                      const SizedBox(
                          width: 30,
                          child: Icon(LucideIcons.map,
                              size: 19, color: spikeMuted)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: cityId,
                            isExpanded: true,
                            hint: Text('اختر مدينة التغطية *',
                                style: spikeTextStyle(
                                    fontSize: 13, color: spikeMuted)),
                            items: list
                                .map((c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name,
                                        style: spikeTextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) => setState(() => cityId = v),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _ReferenceField(
                      controller: maps,
                      icon: LucideIcons.mapPin,
                      hint: 'رابط Google Maps للموقع *',
                      keyboard: TextInputType.url,
                      ltr: true),
                  const SizedBox(height: 7),
                  const Text(
                      'انسخ رابط موقعك من Google Maps والصقه هنا. النظام يحدد الإحداثيات تلقائياً بدون إدخالها يدوياً.',
                      style: TextStyle(
                          fontSize: 10, color: spikeMuted, height: 1.45)),
                  const SizedBox(height: 20),
                  const Text('تفاصيل الاتصال',
                      style:
                          TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _ReferenceField(
                      controller: name,
                      icon: LucideIcons.user,
                      hint: 'اسم المستلم *'),
                  const SizedBox(height: 12),
                  _ReferenceField(
                      controller: phone,
                      icon: LucideIcons.phone,
                      hint: 'رقم الجوال *',
                      keyboard: TextInputType.phone,
                      ltr: true,
                      height: 64),
                  const SizedBox(height: 20),
                  const Text('حفظ العنوان باسم',
                      style:
                          TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _AddressType(
                            type: 'home',
                            title: 'المنزل',
                            icon: LucideIcons.house,
                            selected: _typeKey == 'home',
                            onTap: _setType)),
                    const SizedBox(width: 9),
                    Expanded(
                        child: _AddressType(
                            type: 'office',
                            title: 'مكتب',
                            icon: LucideIcons.building2,
                            selected: _typeKey == 'office',
                            onTap: _setType)),
                    const SizedBox(width: 9),
                    Expanded(
                        child: _AddressType(
                            type: 'other',
                            title: 'أخرى',
                            icon: LucideIcons.mapPinned,
                            selected: _typeKey == 'other',
                            onTap: _setType)),
                  ]),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => setState(() => active = !active),
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      decoration: BoxDecoration(
                          color: card, borderRadius: BorderRadius.circular(17)),
                      child: Row(children: [
                        Container(
                            width: 29,
                            height: 29,
                            decoration: BoxDecoration(
                                color: const Color(0xFFFFF6DF),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.check,
                                size: 17, color: Color(0xFFF0AD14))),
                        const SizedBox(width: 7),
                        const Expanded(
                            child: Text('تعيين كعنوان التوصيل الافتراضي',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700))),
                        Switch(
                            value: active,
                            onChanged: (v) => setState(() => active = v),
                            activeThumbColor: const Color(0xFFF0AD14),
                            activeTrackColor:
                                const Color(0xFFF0AD14).withValues(alpha: .45)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFF4B219),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15))),
                          onPressed: busy ? null : save,
                          child: busy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text('حفظ العنوان',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                            onPressed: () => context.pop(),
                            style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15))),
                            child: const Text('إلغاء')),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _LoginRequired extends StatelessWidget {
  const _LoginRequired({required this.onLogin, this.expired = false});
  final VoidCallback onLogin;
  final bool expired;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 74,
              height: 74,
              decoration: const BoxDecoration(
                  color: Color(0xFFFFF6DF),
                  borderRadius: BorderRadius.all(Radius.circular(24))),
              child: const Icon(LucideIcons.mapPin,
                  size: 32, color: Color(0xFFF0AD14)),
            ),
            const SizedBox(height: 18),
            Text(expired ? 'انتهت صلاحية الجلسة' : 'سجّل الدخول لإدارة عناوينك',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              expired
                  ? 'انتهت جلسة تسجيل الدخول. سجّل الدخول من جديد لاختيار عنوان التوصيل.'
                  : 'عناوين التوصيل مرتبطة بحسابك. سجّل الدخول لاختيار عنوان محفوظ أو إضافة عنوان جديد.',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 12, color: spikeMuted, height: 1.6),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 224,
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(SpikeRadius.control))),
                onPressed: onLogin,
                icon: const Icon(LucideIcons.logIn, size: 18),
                label: const Text('تسجيل الدخول',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      );
}

class _AddressHead extends StatelessWidget {
  const _AddressHead({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17),
          child: Stack(alignment: Alignment.center, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 50,
                height: 40,
                child: Material(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? spikeDarkPanel
                      : const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                      onTap: onBack,
                      borderRadius: BorderRadius.circular(22),
                      child: const Icon(LucideIcons.arrowRight, size: 23)),
                ),
              ),
            ),
          ]),
        ),
      );
}

class _ReferenceField extends StatelessWidget {
  const _ReferenceField(
      {required this.controller,
      required this.icon,
      required this.hint,
      this.keyboard,
      this.ltr = false,
      this.height = 54});
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final TextInputType? keyboard;
  final bool ltr;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1D1D1D)
              : Colors.white,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(children: [
          SizedBox(width: 30, child: Icon(icon, size: 19, color: spikeMuted)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboard,
              textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
              textAlign: ltr ? TextAlign.left : TextAlign.right,
              decoration: InputDecoration(
                  filled: false,
                  hintText: hint,
                  hintStyle: spikeTextStyle(fontSize: 13, color: spikeMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none),
            ),
          ),
        ]),
      );
}

class _AddressType extends StatelessWidget {
  const _AddressType(
      {required this.type,
      required this.title,
      required this.icon,
      required this.selected,
      required this.onTap});
  final String type;
  final String title;
  final IconData icon;
  final bool selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onTap(type),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 83,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFFF9E8)
                : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1D1D1D)
                    : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected
                    ? const Color(0xFFF0AD14)
                    : Theme.of(context).dividerColor,
                width: selected ? 2 : 1),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 23, color: selected ? const Color(0xFFEFaa0A) : null),
            const SizedBox(height: 7),
            Text(title,
                style: TextStyle(
                    fontSize: 12,
                    color: selected ? const Color(0xFFEFaa0A) : null)),
          ]),
        ),
      );
}
