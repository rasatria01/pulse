/// Checks on values the schema cannot constrain.
library;

import '../../core/failures.dart';

final _slug = RegExp(r'^[a-z0-9_-]+$');

String requireName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    throw const ValidationFailure('name is empty', field: 'name');
  }
  return trimmed;
}

/// Lowercase letters, digits, _ and - (PRD F6).
String requireSlug(String slug, {String field = 'slug'}) {
  final lower = slug.trim().toLowerCase();
  if (!_slug.hasMatch(lower)) {
    throw ValidationFailure('invalid slug "$slug"', field: field);
  }
  return lower;
}

/// Aliases are stored comma-separated, so each one must be a slug.
String joinAliases(List<String> aliases) =>
    {for (final a in aliases) requireSlug(a, field: 'aliases')}.join(',');
