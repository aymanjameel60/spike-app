import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import '../../../core/widgets/spike_network_image.dart';

class StoresScreen extends ConsumerStatefulWidget {
  const StoresScreen({super.key});

  @override
  ConsumerState<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends ConsumerState<StoresScreen> {
  String _query = '';
  String _sort = 'relevance';

  Future<void> _showSort() async {
    const options = <(String, String)>[
      ('relevance', 'الأكثر صلة'),
      ('rating', 'الأعلى تقييماً'),
      ('reviews', 'الأكثر مراجعات'),
      ('name', 'الاسم أبجدياً'),
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'الترتيب حسب',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.pop(sheetContext),
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(LucideIcons.x, size: 19, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _sort,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _sort = value);
                  Navigator.pop(sheetContext);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in options)
                      RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: option.$1,
                        title: Text(
                          option.$2,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storesState = ref.watch(storesProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      height: 40,
                      child: Material(
                        color: dark ? spikeDarkPanel : const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(22),
                        child: InkWell(
                          onTap: () => context.canPop()
                              ? context.pop()
                              : context.go('/'),
                          borderRadius: BorderRadius.circular(22),
                          child: const Icon(LucideIcons.arrowRight, size: 23),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'المتاجر',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      height: 40,
                      child: Material(
                        color: dark ? spikeDarkPanel : const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(22),
                        child: InkWell(
                          onTap: _showSort,
                          borderRadius: BorderRadius.circular(22),
                          child: const Tooltip(
                            message: 'ترتيب حسب',
                            child: Icon(LucideIcons.arrowUpDown, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: dark ? spikeDarkPanel : spikeField,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: const InputDecoration(
                    hintText: 'البحث عن متجر',
                    prefixIcon: Icon(LucideIcons.search, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: storesState.when(
                loading: () => const SpikeLoading(),
                error: (error, _) => SpikeErrorState(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(storesProvider),
                ),
                data: (stores) {
                  final q = _query.toLowerCase();
                  final list = stores
                      .where((store) =>
                          q.isEmpty || store.name.toLowerCase().contains(q))
                      .toList();

                  if (_sort == 'name') {
                    list.sort((a, b) => a.name.compareTo(b.name));
                  } else if (_sort == 'rating') {
                    list.sort((a, b) => b.rating.compareTo(a.rating));
                  } else if (_sort == 'reviews') {
                    list.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
                  }

                  if (list.isEmpty) {
                    return const SpikeEmptyState(
                      message: 'لا توجد متاجر مطابقة للفلتر',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(storesProvider);
                      await ref.read(storesProvider.future);
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(17, 0, 17, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final store = list[index];
                        return InkWell(
                          onTap: () => context.push('/store/${store.id}'),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            decoration: BoxDecoration(
                              color: dark ? spikeDarkPanel : spikePanel,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    SizedBox(
                                      height: 150,
                                      width: double.infinity,
                                      child: store.bannerUrl == null
                                          ? Container(
                                              color: dark
                                                  ? Colors.white10
                                                  : Colors.black12,
                                            )
                                          : SpikeNetworkImage(
                                              url: store.bannerUrl,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: 150,
                                            ),
                                    ),
                                    Positioned(
                                      top: 10,
                                      left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: .62),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              store.reviewCount > 0
                                                  ? store.rating.toStringAsFixed(1)
                                                  : '—',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            const Icon(
                                              Icons.star_rounded,
                                              size: 14,
                                              color: Color(0xFFF5B400),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(minHeight: 82),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 58,
                                          height: 58,
                                          clipBehavior: Clip.antiAlias,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFFEEEEEE),
                                            ),
                                          ),
                                          child: store.logoUrl == null
                                              ? const Icon(
                                                  LucideIcons.store,
                                                  size: 22,
                                                  color: Colors.black,
                                                )
                                              : SpikeNetworkImage(
                                                  url: store.logoUrl,
                                                  fit: BoxFit.cover,
                                                  width: 58,
                                                  height: 58,
                                                ),
                                        ),
                                        const SizedBox(width: 11),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  store.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              if (store.isVerified) ...[
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  LucideIcons.badgeCheck,
                                                  size: 15,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          LucideIcons.arrowLeft,
                                          size: 20,
                                          color: spikeMuted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
