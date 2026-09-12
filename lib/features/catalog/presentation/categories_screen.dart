import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import '../../../core/widgets/spike_network_image.dart';
import '../../../models/category.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  void _openCategory(BuildContext context, CategoryModel category) {
    if (category.actionType == 'all_categories' || category.showAsMore) {
      context.go('/categories');
      return;
    }
    if (category.actionType == 'section' &&
        (category.actionTarget ?? '').isNotEmpty) {
      context.push('/section/${category.actionTarget}');
      return;
    }
    if (category.effectiveCollectionId != null) {
      context.push(
        '/products?collection=${Uri.encodeComponent(category.effectiveCollectionId!)}&title=${Uri.encodeComponent(category.name)}',
      );
      return;
    }
    final id = category.effectiveCategoryId ?? category.id;
    context.push('/category/${Uri.encodeComponent(id)}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The customer web is the UI/UX source of truth. Use the same ordered
    // category list that powers Home, then apply the exact web visibility
    // rules for the "all categories" screen without a root-only filter.
    final state = ref.watch(homeDataProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mutedIcon = Theme.of(context).colorScheme.onSurface.withValues(alpha: .24);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 8, 17, 0),
            child: SizedBox(
              height: 60,
              child: Row(children: [
                IconButton(
                  onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                  icon: const Icon(LucideIcons.arrowRight, size: 22),
                ),
                const Spacer(),
                const Text('تسوق حسب الفئة', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                const Spacer(),
                const SizedBox(width: 48),
              ]),
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const SpikeLoading(),
              error: (e, _) => SpikeErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(homeDataProvider),
              ),
              data: (home) {
                final visible = home.categories
                    .where((c) =>
                        c.enabled &&
                        !c.showAsMore &&
                        c.actionType != 'all_categories')
                    .toList();
                return visible.isEmpty
                    ? const SpikeEmptyState(message: 'لا توجد فئات منشورة بعد')
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(homeDataProvider);
                          await ref.read(homeDataProvider.future);
                        },
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(17, 5, 17, 24),
                          itemCount: visible.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 11,
                            mainAxisSpacing: 20,
                            mainAxisExtent: 124,
                          ),
                          itemBuilder: (context, i) {
                            final c = visible[i];
                            return InkWell(
                              onTap: () => _openCategory(context, c),
                              borderRadius: BorderRadius.circular(21),
                              child: Column(children: [
                                Container(
                                  width: 81,
                                  height: 81,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: dark ? spikeDarkPanel : spikePanel,
                                    borderRadius: BorderRadius.circular(21),
                                  ),
                                  child: c.imageUrl == null
                                      ? Icon(LucideIcons.image, color: mutedIcon)
                                      : SpikeNetworkImage(
                                          url: c.imageUrl,
                                          fit: BoxFit.cover,
                                          width: 81,
                                          height: 81,
                                        ),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  c.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.32),
                                ),
                              ]),
                            );
                          },
                        ),
                      );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
