import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../models/home_section.dart';
import '../../../widgets/dynamic_home_sections.dart';

class HomeSectionScreen extends ConsumerWidget {
  const HomeSectionScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<HomeSectionModel>(
      future: ref.read(homeRepositoryProvider).section(id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error?.toString() ?? 'تعذر تحميل القسم',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final section = snapshot.data!;
        final pageSection = HomeSectionModel(
          id: section.id,
          title: section.title,
          contentType: section.contentType,
          sourceType: section.sourceType,
          referenceId: section.referenceId,
          showAll: false,
          showAllTargetType: section.showAllTargetType,
          showAllTargetId: section.showAllTargetId,
          sortOrder: section.sortOrder,
          items: section.items,
        );
        return Scaffold(
          appBar: AppBar(title: Text(section.title)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: DynamicHomeSections(sections: [pageSection]),
          ),
        );
      },
    );
  }
}
