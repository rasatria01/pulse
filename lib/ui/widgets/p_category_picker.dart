// Pick a category, or add one by typing its name.
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../core/failures.dart';
import '../../domain/entities/category.dart';
import '../strings.dart';
import '../tokens.dart';
import 'p_chip.dart';
import 'p_sheet.dart';

/// The #handle for a category [name]: "Makan siang" -> "makan-siang". Empty
/// when the name has no letter or digit a handle can hold.
String categorySlug(String name) => name
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), '-')
    .replaceAll(RegExp('[^a-z0-9_-]'), '')
    .replaceAll(RegExp('-{2,}'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

/// A new category of [kind] called [name], in the first identity colour its
/// kind does not use yet, listed after [existing].
CategoryInput newCategoryInput(
  String name,
  CategoryKind kind,
  List<Category> existing,
) {
  final used = {
    for (final c in existing)
      if (c.kind == kind && !c.isArchived) c.color,
  };
  final free = [
    for (final c in MelaIdentity.all)
      if (!used.contains(c.toARGB32())) c.toARGB32(),
  ];
  final count = existing.where((c) => c.kind == kind).length;
  return CategoryInput(
    name: name.trim(),
    slug: categorySlug(name),
    kind: kind,
    color: free.isNotEmpty
        ? free.first
        : MelaIdentity.all[count % MelaIdentity.all.length].toARGB32(),
    icon: 'tag',
    sortOrder:
        existing.fold(0, (max, c) => c.sortOrder > max ? c.sortOrder : max) + 1,
  );
}

/// The message for a failed category save.
String categoryError(Object error, String slug) => switch (error) {
  ValidationFailure() when slug.isEmpty => MelaStrings.categoryNameError,
  ConflictFailure() => MelaStrings.categoryTaken(slug),
  _ => MelaStrings.saveFailed,
};

/// Completes with the picked or added category id, or null if dismissed.
/// [options] are the live categories of one kind; [onCreate] adds one by name
/// and returns its id.
Future<String?> showCategoryPicker(
  BuildContext context, {
  required String title,
  required List<Category> options,
  required Future<String> Function(String name) onCreate,
  String? selected,
  String initialQuery = '',
}) => showPSheet<String>(
  context: context,
  builder: (context) => _CategoryPicker(
    title: title,
    options: options,
    onCreate: onCreate,
    selected: selected,
    initialQuery: initialQuery,
  ),
);

class _CategoryPicker extends StatefulWidget {
  const _CategoryPicker({
    required this.title,
    required this.options,
    required this.onCreate,
    required this.selected,
    required this.initialQuery,
  });

  final String title;
  final List<Category> options;
  final Future<String> Function(String name) onCreate;
  final String? selected, initialQuery;

  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  late final _query = TextEditingController(text: widget.initialQuery)
    ..addListener(() => setState(() => _error = null));
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _create(String name) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final id = await widget.onCreate(name);
      if (mounted) Navigator.of(context).pop(id);
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = categoryError(e, categorySlug(name));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim();
    final lower = query.toLowerCase();
    final slug = categorySlug(query);
    final shown = [
      for (final c in widget.options)
        if (lower.isEmpty ||
            c.name.toLowerCase().contains(lower) ||
            (slug.isNotEmpty &&
                [c.slug, ...c.aliases].any((s) => s.contains(slug))))
          c,
    ];
    final exact = widget.options
        .where(
          (c) =>
              c.name.toLowerCase() == lower ||
              (slug.isNotEmpty && [c.slug, ...c.aliases].contains(slug)),
        )
        .firstOrNull;
    final error = _error;
    return PSheet(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MelaSpace.s3,
        children: [
          Semantics(
            label: MelaStrings.findCategory,
            child: ShadInput(
              key: const ValueKey('category-query'),
              controller: _query,
              placeholder: const Text(MelaStrings.findCategory),
              leading: const Icon(LucideIcons.search, size: MelaSize.iconSm),
              onSubmitted: (_) {
                if (exact != null) {
                  Navigator.of(context).pop(exact.id);
                } else if (query.isNotEmpty) {
                  _create(query);
                }
              },
            ),
          ),
          Wrap(
            spacing: MelaSpace.s2,
            runSpacing: MelaSpace.s2,
            children: [
              for (final c in shown)
                PChip(
                  label: c.name,
                  dotColor: c.color,
                  selected: c.id == widget.selected,
                  onPressed: () => Navigator.of(context).pop(c.id),
                ),
              if (query.isNotEmpty && exact == null)
                PChip(
                  key: const ValueKey('category-create'),
                  label: MelaStrings.addCategory(query),
                  icon: LucideIcons.plus,
                  tone: PChipTone.placeholder,
                  onPressed: _busy ? null : () => _create(query),
                ),
            ],
          ),
          if (error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: MelaText.caption.copyWith(
                  color: ShadTheme.of(context).colorScheme.destructive,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
