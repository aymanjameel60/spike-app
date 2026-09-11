import 'package:flutter/material.dart';

class SpikeLoading extends StatelessWidget {
  const SpikeLoading({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
}

class SpikeErrorState extends StatelessWidget {
  const SpikeErrorState({super.key, required this.onRetry, this.message = 'تعذر تحميل البيانات'});
  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 34),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ]),
        ),
      );
}

class SpikeEmptyState extends StatelessWidget {
  const SpikeEmptyState({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .55),
              height: 1.5,
            ),
          ),
        ),
      );
}

void showSpikeToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(34, 0, 34, 18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        backgroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w400, height: 1.35),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
}

Future<bool> showSpikeConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'تأكيد',
  String cancelText = 'إلغاء',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (danger) ...[
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Color(0xFFFFEBEC), shape: BoxShape.circle),
              child: const Text('!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFFAD0009))),
            ),
            const SizedBox(height: 14),
          ],
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, height: 1.55)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: danger ? const Color(0xFFAD0009) : Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmText),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(cancelText),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
  return result ?? false;
}
