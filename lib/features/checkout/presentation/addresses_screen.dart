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
        child: Column(
          children: [
            _AddressHead(
              title: 'اختيار العنوان',
              onBack: () => context.canPop() ? context.pop() : context.go('/'),
            ),
            Expanded(
              child: session.when(
                loading: () => const SpikeLoading(),
                error: (e, _) => SpikeErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(hasSessionProvider),
                ),
                data: (loggedIn) => !loggedIn
                    ? _LoginRequired(onLogin: () => _goLogin(context))
                    : state.when(
                        loading: () => const SpikeLoading(),
                        error: (e, _) => e is ApiException && e.statusCode == 401
                            ? _LoginRequired(
                                expired: true,
                                onLogin: () => _goLogin(context),
                              )
                            : SpikeErrorState(
                                message: e.toString(),
                                onRetry: () => ref.invalidate(addressesProvider),
                              ),
                        data: (items) => RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(addressesProvider);
                            await ref.read(addressesProvider.future);
                          },
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(17, 10, 17, 24),
                            children: [
                              const Text(
                                'اختر عنوان التوصيل أو عدّل أحد العناوين المحفوظة.',
                                style: TextStyle(fontSize: 12, color: spikeMuted),
                              ),
                              const SizedBox(height: 14),
                              if (items.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 38),
                                  child: Column(
                                    children: [
                                      Icon(LucideIcons.mapPin, size: 38, color: spikeMuted),
                                      SizedBox(height: 12),
                                      Text(
                                        'لا توجد عناوين محفوظة',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'أضف عنوان التوصيل حتى تتمكن من إكمال الطلب.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 11, color: spikeMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              for (final a in items) ...[
                                Container(
                                  decoration: BoxDecoration(
                                    color: card,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: a.isActive
                                          ? Theme.of(context).colorScheme.onSurface
                                          : Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () async {
                                            try {
                                              await ref
                                                  .read(commerceRepositoryProvider)
                                                  .activateAddress(a.id);
                                              ref.invalidate(addressesProvider);
                                              if (context.mounted) {
                                                showSpikeToast(context, 'تم اختيار العنوان');
                                                context.pop(a.id);
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                showSpikeToast(context, e.toString());
                                              }
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(18),
                                          child: Container(
                                            constraints: const BoxConstraints(minHeight: 86),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                            child: Row(
                                              children: [
                                                const SizedBox(
                                                  width: 28,
                                                  child: Icon(LucideIcons.mapPin, size: 19),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        a.cityName,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        a.addressLine,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontSize: 10),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '${a.recipientName} • ${a.phone}',
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontSize: 10, color: spikeMuted),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 25,
                                                  child: a.isActive
                                                      ? const Icon(Icons.check, size: 18)
                                                      : null,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          await context.push('/address-form', extra: a);
                                          ref.invalidate(addressesProvider);
                                        },
                                        child: const Text(
                                          'تعديل',
                                          style: TextStyle(
                                            fontSize: 12,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 50,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.onSurface,
                                    foregroundColor: Theme.of(context).colorScheme.surface,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () async {
                                    await context.push('/address-form');
                                    ref.invalidate(addressesProvider);
                                  },
                                  icon: const Icon(LucideIcons.plus, size: 18),
                                  label: const Text(
                                    'إضافة عنوان جديد',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
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
  late final TextEditingController recipient;
  late final TextEditingController phone;
  late final TextEditingController maps;
  String? cityId;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    line = TextEditingController(text: a?.addressLine ?? '');
    recipient = TextEditingController(text: a?.recipientName ?? '');
    phone = TextEditingController(text: a?.phone ?? '');
    maps = TextEditingController(text: a?.googleMapsUrl ?? '');
    cityId = a?.cityId;
  }

  @override
  void dispose() {
    line.dispose();
    recipient.dispose();
    phone.dispose();
    maps.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final a = widget.address;
    if (a == null || busy) return;
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('حذف العنوان'),
            content: const Text('هل تريد حذف هذا العنوان؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف'),
              ),
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
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy) return;
    final governorate = cityId?.trim() ?? '';
    final detailedAddress = line.text.trim();
    final recipientName = recipient.text.trim();
    final recipientPhone = phone.text.trim();

    if (governorate.isEmpty ||
        detailedAddress.isEmpty ||
        recipientName.isEmpty ||
        recipientPhone.isEmpty) {
      showSpikeToast(
        context,
        'أكمل المحافظة والعنوان التفصيلي واسم المستلم ورقمه',
      );
      return;
    }

    setState(() => busy = true);
    try {
      final repository = ref.read(commerceRepositoryProvider);
      if (widget.address == null) {
        final existing = await repository.addresses();
        await repository.createAddress(
          cityId: governorate,
          label: '',
          recipientName: recipientName,
          phone: recipientPhone,
          addressLine: detailedAddress,
          googleMapsUrl: maps.text.trim(),
          isActive: existing.isEmpty,
        );
      } else {
        await repository.updateAddress(
          widget.address!.id,
          cityId: governorate,
          label: '',
          recipientName: recipientName,
          phone: recipientPhone,
          addressLine: detailedAddress,
          googleMapsUrl: maps.text.trim(),
          isActive: widget.address!.isActive,
        );
      }
      ref.invalidate(addressesProvider);
      if (mounted) {
        showSpikeToast(context, 'تم حفظ العنوان');
        context.pop();
      }
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
        child: Column(
          children: [
            _AddressHead(
              title: widget.address == null ? 'إضافة عنوان جديد' : 'تعديل العنوان',
              onBack: () => context.canPop() ? context.pop() : context.go('/'),
              action: widget.address == null
                  ? null
                  : IconButton(
                      onPressed: busy ? null : _delete,
                      icon: const Icon(
                        LucideIcons.trash2,
                        size: 21,
                        color: Color(0xFFB42318),
                      ),
                    ),
            ),
            Expanded(
              child: cities.when(
                loading: () => const SpikeLoading(),
                error: (e, _) => SpikeErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(citiesProvider),
                ),
                data: (list) => ListView(
                  padding: const EdgeInsets.fromLTRB(17, 0, 17, 20),
                  children: [
                    const Text(
                      'تفاصيل العنوان',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: card,
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 30,
                            child: Icon(LucideIcons.map, size: 19, color: spikeMuted),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: cityId,
                                isExpanded: true,
                                hint: Text(
                                  'المحافظة *',
                                  style: spikeTextStyle(fontSize: 13, color: spikeMuted),
                                ),
                                items: list
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name, style: spikeTextStyle(fontSize: 13)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(() => cityId = v),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ReferenceField(
                      controller: line,
                      icon: LucideIcons.house,
                      hint: 'العنوان التفصيلي *',
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'بيانات المستلم',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    _ReferenceField(
                      controller: recipient,
                      icon: LucideIcons.user,
                      hint: 'اسم المستلم *',
                    ),
                    const SizedBox(height: 12),
                    _ReferenceField(
                      controller: phone,
                      icon: LucideIcons.phone,
                      hint: 'رقم المستلم *',
                      keyboard: TextInputType.phone,
                      ltr: true,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'الموقع',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    _ReferenceField(
                      controller: maps,
                      icon: LucideIcons.mapPin,
                      hint: 'رابط Google Maps (اختياري)',
                      keyboard: TextInputType.url,
                      ltr: true,
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Google Maps اختياري ويساعد على حساب التوصيل بدقة أكبر.',
                      style: TextStyle(fontSize: 10, color: spikeMuted, height: 1.45),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: spikeYellow,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: busy ? null : save,
                        child: busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'حفظ العنوان',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: busy ? null : () => context.pop(),
                        child: const Text('إلغاء'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
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
                      borderRadius: BorderRadius.circular(22),
                      onTap: onBack,
                      child: const Icon(LucideIcons.arrowRight, size: 23),
                    ),
                  ),
                ),
              ),
              if (action != null) Align(alignment: Alignment.centerLeft, child: action!),
            ],
          ),
        ),
      );
}

class _ReferenceField extends StatelessWidget {
  const _ReferenceField({
    required this.controller,
    required this.icon,
    required this.hint,
    this.keyboard,
    this.ltr = false,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final TextInputType? keyboard;
  final bool ltr;

  @override
  Widget build(BuildContext context) => Container(
        minHeight: 54,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1D1D1D)
              : Colors.white,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(15),
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboard,
          textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
          style: spikeTextStyle(fontSize: 13),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hint,
            hintStyle: spikeTextStyle(fontSize: 13, color: spikeMuted),
            prefixIcon: Icon(icon, size: 19, color: spikeMuted),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.lock, size: 36, color: spikeMuted),
              const SizedBox(height: 12),
              Text(
                expired ? 'انتهت الجلسة' : 'تسجيل الدخول مطلوب',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              Text(
                expired
                    ? 'سجّل الدخول مرة أخرى للوصول إلى عناوينك.'
                    : 'سجّل الدخول لإدارة عناوين التوصيل.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: spikeMuted),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onLogin, child: const Text('تسجيل الدخول')),
            ],
          ),
        ),
      );
}
