import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import '../../../core/widgets/spike_network_image.dart';
import '../../../models/product.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialQuery);
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final field = dark ? spikeDarkPanel : const Color(0xFFE7E7E7);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 8, 17, 12),
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
                  const SizedBox(width: 9),
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: field,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                        decoration: InputDecoration(
                          hintText: 'ابحث عن المنتجات ...',
                          hintStyle: spikeTextStyle(
                            fontSize: 12,
                            color: const Color(0xFFBDBDBD),
                          ),
                          prefixIcon:
                              const Icon(LucideIcons.search, size: 20),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon:
                                      const Icon(LucideIcons.x, size: 17),
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _content()),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    if (_query.isEmpty) {
      return const _SearchEmpty();
    }

    final state = ref.watch(allProductsProvider);
    return state.when(
      loading: () => const SpikeLoading(),
      error: (error, _) => SpikeErrorState(
        message: error.toString(),
        onRetry: () => ref.invalidate(allProductsProvider),
      ),
      data: (products) {
        final q = _query.toLowerCase();
        final results = products.where((product) {
          return product.name.toLowerCase().contains(q) ||
              product.storeName.toLowerCase().contains(q) ||
              (product.categoryName ?? '').toLowerCase().contains(q);
        }).toList();

        if (results.isEmpty) {
          return SpikeEmptyState(message: 'لا توجد نتائج لـ "$_query"');
        }

        return ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(17, 4, 17, 24),
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _SearchResult(product: results[index]),
        );
      },
    );
  }
}

class _SearchEmpty extends StatelessWidget {
  const _SearchEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.search, size: 30),
            const SizedBox(height: 12),
            const Text(
              'ابحث عن منتج أو متجر',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              'اكتب اسم المنتج أو الفئة أو المتجر.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: .55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResult extends StatelessWidget {
  const _SearchResult({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final subtitle = product.storeName.trim().isNotEmpty
        ? product.storeName
        : (product.categoryName ?? '');

    return Material(
      color: dark ? spikeDarkPanel : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => context.push('/product/${product.id}'),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: product.imageUrl == null || product.imageUrl!.isEmpty
                      ? Container(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: .06),
                          child: const Icon(LucideIcons.package, size: 20),
                        )
                      : SpikeNetworkImage(
                          url: product.imageUrl!,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: spikeMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(LucideIcons.chevronLeft, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
