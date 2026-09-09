import 'package:flutter/material.dart';

class SpikeLoading extends StatelessWidget {
  const SpikeLoading({super.key});
  @override Widget build(BuildContext context) => const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
}

class SpikeErrorState extends StatelessWidget {
  const SpikeErrorState({super.key, required this.onRetry, this.message = 'تعذر تحميل البيانات'});
  final VoidCallback onRetry;
  final String message;
  @override Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, size: 34),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
      ]),
    ),
  );
}

class SpikeEmptyState extends StatelessWidget {
  const SpikeEmptyState({super.key, required this.message});
  final String message;
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Center(child: Text(message, style: const TextStyle(color: Colors.black54))),
  );
}

void showSpikeToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w400)), duration: const Duration(seconds: 2)));
}
