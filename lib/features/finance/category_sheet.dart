import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shad/shad.dart';

import '../../app/di.dart';
import '../../core/failures.dart';
import '../../domain/entities/category.dart';
import '../../ui/strings.dart';
import '../../ui/widgets/common.dart' show PTapTarget;
import '../../ui/widgets/widgets.dart';
import 'finance_strings.dart';
import 'form_fields.dart';

/// Adds a category of [kind], or edits or archives [category].
class CategorySheet extends ConsumerStatefulWidget {
  const CategorySheet({
    super.key,
    this.category,
    this.kind = CategoryKind.outcome,
  });

  final Category? category;
  final CategoryKind kind;

  @override
  ConsumerState<CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<CategorySheet> {
  late final Category? _old = widget.category;
  late final _name = TextEditingController(text: _old?.name);
  late final _slug = TextEditingController(text: _old?.slug);
  late CategoryKind _kind = _old?.kind ?? widget.kind;
  late int _color =
      _old?.color ??
      newCategoryInput(
        '',
        widget.kind,
        ref.read(categoriesProvider).value ?? const [],
      ).color;
  late String _icon = _old?.icon ?? 'tag';
  bool _confirmArchive = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() write, String slug) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await write();
      if (mounted) Navigator.of(context).pop();
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = categoryError(e, slug);
      });
    }
  }

  void _save() {
    final name = _name.text.trim();
    final typed = _slug.text.trim().toLowerCase();
    final slug = typed.isEmpty ? categorySlug(name) : typed;
    if (name.isEmpty) {
      setState(() => _error = FinanceStrings.nameError);
      return;
    }
    if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(slug)) {
      setState(() => _error = FinanceStrings.handleError);
      return;
    }
    final repository = ref.read(categoryRepositoryProvider);
    final old = _old;
    if (old != null) {
      _run(
        () => repository.update(
          old.id,
          CategoryPatch(name: name, slug: slug, color: _color, icon: _icon),
        ),
        slug,
      );
      return;
    }
    final fresh = newCategoryInput(
      name,
      _kind,
      ref.read(categoriesProvider).value ?? const [],
    );
    _run(
      () => repository.create(
        fresh.copyWith(slug: slug, color: _color, icon: _icon),
      ),
      slug,
    );
  }

  Widget _input(String label, TextEditingController controller) =>
      LabelledField(
        label: label,
        child: ShadInput(key: ValueKey(label), controller: controller),
      );

  @override
  Widget build(BuildContext context) {
    final old = _old;
    final colors = ShadTheme.of(context).colorScheme;
    final error = _error;
    return PSheet(
      title: old == null
          ? FinanceStrings.addCategory
          : FinanceStrings.editCategory,
      footer: [
        if (old != null && !old.isSystem && !old.isArchived)
          _confirmArchive
              ? PButton.destructive(
                  label: FinanceStrings.confirmArchive,
                  onPressed: () => _run(
                    () => ref.read(categoryRepositoryProvider).archive(old.id),
                    old.slug,
                  ),
                )
              : PButton.ghost(
                  label: FinanceStrings.archive,
                  onPressed: () => setState(() => _confirmArchive = true),
                ),
        PButton.primary(
          label: MelaStrings.save,
          onPressed: _busy ? null : _save,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MelaSpace.s3,
        children: [
          if (old == null)
            LabelledField(
              label: FinanceStrings.type,
              child: Wrap(
                spacing: MelaSpace.s2,
                children: [
                  for (final (kind, label) in const [
                    (CategoryKind.outcome, MelaStrings.expense),
                    (CategoryKind.income, MelaStrings.income),
                  ])
                    PChip(
                      label: label,
                      selected: _kind == kind,
                      onPressed: () => setState(() => _kind = kind),
                    ),
                ],
              ),
            ),
          _input(FinanceStrings.name, _name),
          _input(FinanceStrings.categoryHandle, _slug),
          LabelledField(
            label: FinanceStrings.colour,
            child: Wrap(
              spacing: MelaSpace.s2,
              runSpacing: MelaSpace.s2,
              children: [
                for (final (i, color) in MelaIdentity.all.indexed)
                  PChip(
                    label: FinanceStrings.colourNames[i],
                    dotColor: color.toARGB32(),
                    selected: color.toARGB32() == _color,
                    onPressed: () => setState(() => _color = color.toARGB32()),
                  ),
              ],
            ),
          ),
          LabelledField(
            label: FinanceStrings.icon,
            child: Wrap(
              spacing: MelaSpace.s1,
              runSpacing: MelaSpace.s1,
              children: [
                for (final name in categoryIcons)
                  PTapTarget(
                    key: ValueKey('icon-$name'),
                    label:
                        '${FinanceStrings.icon} ${name.replaceAll('-', ' ')}',
                    selected: name == _icon,
                    onTap: () => setState(() => _icon = name),
                    child: Container(
                      width: MelaSize.touch,
                      height: MelaSize.touch,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: name == _icon
                            ? Border.all(color: colors.foreground)
                            : null,
                      ),
                      child: PIconTile(
                        icon: melaIcon(name),
                        color: name == _icon ? identityColor(_color) : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_confirmArchive)
            const Text(FinanceStrings.categoryArchiveWarning),
          if (error != null) FormError(error),
        ],
      ),
    );
  }
}
