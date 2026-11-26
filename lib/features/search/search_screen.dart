import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shad/shad.dart';

import '../../app/di.dart';
import '../../core/routes.dart';
import '../../domain/entities/search.dart';
import '../../domain/entities/tag.dart';
import '../../ui/strings.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/widgets.dart';
import 'controllers/search_controller.dart';
import 'search_strings.dart';

const _types = [
  (null, SearchStrings.all),
  (EntityType.transaction, SearchStrings.transactions),
  (EntityType.actionItem, SearchStrings.tasks),
  (EntityType.note, SearchStrings.notes),
];

const _icons = {
  EntityType.transaction: LucideIcons.receiptText,
  EntityType.actionItem: LucideIcons.listTodo,
  EntityType.note: LucideIcons.stickyNote,
};

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  Future<void> _open(SearchHit hit) async {
    final router = GoRouter.of(context);
    switch (hit.type) {
      case EntityType.transaction:
        router.go(Routes.finance);
      case EntityType.actionItem:
        // A scheduled item lives in Calendar, the rest in Tasks (PRD F4).
        final item = await ref
            .read(actionItemRepositoryProvider)
            .find(hit.entityId);
        if (mounted) {
          router.go(
            item?.scheduledStart == null ? Routes.tasks : Routes.calendar,
          );
        }
      case EntityType.note:
        await router.push<void>('${Routes.notes}/${hit.entityId}');
        // The note may have been changed or deleted there.
        if (mounted) {
          await ref.read(searchControllerProvider.notifier).search();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (:text, :type, :results) = ref.watch(searchControllerProvider);
    final controller = ref.read(searchControllerProvider.notifier);
    final hits = results?.value ?? const <SearchHit>[];

    final Widget body;
    if (results == null) {
      body = text.trim().isEmpty
          ? const EmptyState(
              icon: LucideIcons.search,
              title: PulseStrings.searchEmpty,
            )
          : const SizedBox.shrink();
    } else if (results.hasError) {
      body = const EmptyState(
        icon: LucideIcons.circleAlert,
        title: SearchStrings.failed,
      );
    } else if (hits.isEmpty) {
      body = const EmptyState(
        icon: LucideIcons.searchX,
        title: SearchStrings.noResults,
        body: SearchStrings.noResultsBody,
      );
    } else {
      // The repository groups by type: a header goes where the type changes.
      final rows = <Object>[
        for (final (i, hit) in hits.indexed) ...[
          if (i == 0 || hits[i - 1].type != hit.type) hit.type,
          hit,
        ],
      ];
      body = ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: rows.length,
        itemBuilder: (context, i) => switch (rows[i]) {
          final SearchHit hit => _Hit(
            key: ValueKey((hit.type, hit.entityId)),
            hit: hit,
            onTap: () => _open(hit),
          ),
          final type => PSectionHeader(
            _types.firstWhere((t) => t.$1 == type).$2,
          ),
        },
      );
    }

    return PScreen(
      title: PulseStrings.search,
      onBack: context.pop,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: PulseSpace.s2,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PulseSpace.s4),
            child: Semantics(
              label: SearchStrings.field,
              child: ShadInput(
                autofocus: true,
                placeholder: const Text(SearchStrings.placeholder),
                onChanged: controller.setText,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PulseSpace.s4),
            child: PChipRow(
              children: [
                for (final (value, label) in _types)
                  PChip(
                    key: ValueKey('type-${value?.name ?? 'all'}'),
                    field: SearchStrings.type,
                    label: label,
                    selected: type == value,
                    onPressed: () => controller.setType(value),
                  ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Hit extends StatelessWidget {
  const _Hit({super.key, required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final title = hit.title.isEmpty ? SearchStrings.untitled : hit.title;
    final snippet = hit.snippet.replaceAll(RegExp(r'\s+'), ' ').trim();
    return PTapTarget(
      label: [title, if (snippet.isNotEmpty) snippet].join(', '),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PulseSpace.s4,
          vertical: PulseSpace.s3,
        ),
        child: Row(
          spacing: PulseSpace.s3,
          children: [
            PIconTile(icon: _icons[hit.type]!),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PulseText.bodyStrong,
                  ),
                  if (snippet.isNotEmpty)
                    Text(
                      snippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PulseText.caption.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
