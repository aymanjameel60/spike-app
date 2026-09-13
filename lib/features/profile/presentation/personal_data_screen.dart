import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/providers.dart';
import '../../../core/api_config.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';

class PersonalDataScreen extends ConsumerStatefulWidget {
  const PersonalDataScreen({super.key});

  @override
  ConsumerState<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends ConsumerState<PersonalDataScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final code = TextEditingController();
  bool busy = false;
  bool seeded = false;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (x == null) return;
    setState(() => busy = true);
    try {
      await ref.read(authRepositoryProvider).uploadAvatar(x.path);
      ref.invalidate(currentUserProvider);
      if (mounted) showSpikeToast(context, 'تم تحديث الصورة');
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _saveName() async {
    if (name.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile(name: name.text.trim());
      ref.invalidate(currentUserProvider);
      if (mounted) showSpikeToast(context, 'تم حفظ التعديلات');
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _requestPhone() async {
    if (phone.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      await ref.read(authRepositoryProvider).requestPhoneChange(phone.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      _showOtpSheet();
      showSpikeToast(context, 'تم إرسال رمز التحقق');
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verifyPhone() async {
    if (code.text.trim().length != 6) {
      showSpikeToast(context, 'أدخل رمز التحقق المكوّن من 6 أرقام');
      return;
    }
    setState(() => busy = true);
    try {
      await ref.read(authRepositoryProvider).verifyPhoneChange(code.text.trim());
      ref.invalidate(currentUserProvider);
      if (!mounted) return;
      Navigator.pop(context);
      showSpikeToast(context, 'تم تحديث رقم الجوال');
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _showEditProfileSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            17,
            10,
            17,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 22,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(sheetContext).dividerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'تعديل الملف الشخصي',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(LucideIcons.x, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : _pickAvatar,
                  icon: const Icon(LucideIcons.camera, size: 17),
                  label: const Text('تغيير الصورة'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'الاسم',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: name,
                decoration: const InputDecoration(hintText: 'الاسم الكامل'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 39,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: spikeRed),
                  onPressed: busy
                      ? null
                      : () async {
                          await _saveName();
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                  child: const Text(
                    'حفظ التعديلات',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhoneSheet() {
    code.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            17,
            10,
            17,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 22,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(sheetContext).dividerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Center(child: Icon(LucideIcons.phone, size: 24)),
              const SizedBox(height: 12),
              const Text(
                'تغيير رقم الجوال',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'أدخل رقم الجوال الجديد وسنرسل إليه رمز تحقق OTP لتأكيد الرقم.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: spikeMuted, height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(hintText: '967 700 000 000'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 39,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: spikeRed),
                  onPressed: busy ? null : _requestPhone,
                  child: const Text('إرسال رمز التحقق'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOtpSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            17,
            10,
            17,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 22,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(sheetContext).dividerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Center(child: Icon(LucideIcons.messageSquare, size: 24)),
              const SizedBox(height: 12),
              const Text(
                'تأكيد رقم الجوال',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'أرسلنا رمز تحقق إلى ${phone.text.trim()}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: spikeMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: code,
                maxLength: 6,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: '••••••',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 39,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: spikeRed),
                  onPressed: busy ? null : _verifyPhone,
                  child: const Text('تأكيد الرقم'),
                ),
              ),
              TextButton(
                onPressed: busy ? null : _requestPhone,
                child: const Text('إعادة إرسال الرمز'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(currentUserProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final panel = dark ? spikeDarkPanel : spikePanel;
    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي'), centerTitle: true),
      body: state.when(
        loading: () => const SpikeLoading(),
        error: (e, _) => SpikeErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
        data: (u) {
          if (u == null) return const SpikeEmptyState(message: 'سجّل الدخول أولاً');
          if (!seeded) {
            seeded = true;
            name.text = '${u['name'] ?? ''}';
            phone.text = '${u['phone'] ?? ''}';
          }
          final rawAvatar = '${u['avatar_url'] ?? u['avatarUrl'] ?? ''}'.trim();
          final avatar = ApiConfig.resolveMedia(rawAvatar);
          final country = '${u['country'] ?? u['country_name'] ?? '—'}';

          return ListView(
            padding: const EdgeInsets.fromLTRB(17, 0, 17, 28),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.onSurface,
                          width: 1,
                        ),
                      ),
                      child: CircleAvatar(
                        backgroundColor: surface,
                        backgroundImage: avatar.isEmpty
                            ? null
                            : CachedNetworkImageProvider(avatar),
                        child: avatar.isEmpty
                            ? const Icon(LucideIcons.userRound, size: 30)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${u['name'] ?? ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${u['email'] ?? ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: spikeMuted),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_outlined, size: 16),
                          SizedBox(width: 5),
                          Text(
                            'تم التحقق',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 39,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : _showEditProfileSheet,
                  icon: const Icon(LucideIcons.pencil, size: 18),
                  label: const Text(
                    'تعديل الملف الشخصي',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'معلومات الحساب',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(24),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _InfoRow(
                      icon: LucideIcons.phone,
                      label: 'الجوال',
                      value: '${u['phone'] ?? '—'}',
                      verified: true,
                      onEdit: busy ? null : _showPhoneSheet,
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      endIndent: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .08),
                    ),
                    _InfoRow(
                      icon: LucideIcons.globe2,
                      label: 'البلد',
                      value: country,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.verified = false,
    this.onEdit,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool verified;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(icon, size: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 9, color: spikeMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (verified) ...[
              const Icon(Icons.verified_outlined, size: 16),
              const SizedBox(width: 4),
              const Text(
                'تم التحقق',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
            ],
            if (onEdit != null)
              IconButton(
                onPressed: onEdit,
                icon: const Icon(LucideIcons.pencil, size: 17),
              ),
          ],
        ),
      ),
    );
  }
}
