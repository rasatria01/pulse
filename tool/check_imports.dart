// Enforces the PRD section 7 import table. Run: dart run tool/check_imports.dart
import 'dart:io';

const _domainPackages = {'meta', 'collection', 'freezed_annotation'};
const _uiPackages = {'flutter', 'shad', 'intl'};
// Storage and platform plugins: screens reach these only through domain/.
const _featureBannedPackages = {
  'drift',
  'drift_flutter',
  'sqlite3',
  'sqlite3_flutter_libs',
  'flutter_local_notifications',
  'timezone',
  'flutter_timezone',
  'share_plus',
  'file_picker',
};

final _directive = RegExp(
  r'^\s*(?:import|export|part)\s+(?!of\b)[^;]*;',
  multiLine: true,
);
final _quoted = RegExp(r'''['"]([^'"]+)['"]''');
final _wallClock = RegExp(r'\bDateTime\s*\.\s*(now|timestamp)\b');
final _double = RegExp(r'\bdouble\b|\btoDouble\b');
// Strings and both comment forms in one pass, so '//' in a string is not a comment.
final _comment = r'//[^\n]*|/\*[\s\S]*?\*/';
final _string =
    r'''\'\'\'[\s\S]*?\'\'\'|"{3}[\s\S]*?"{3}|'(?:\\.|[^'\\\n])*'|"(?:\\.|[^"\\\n])*"''';
final _noise = RegExp('($_comment)|$_string');
const _platformLibs = {'dart:io', 'dart:ffi', 'dart:ui'};
const _layers = {'app', 'core', 'domain', 'data', 'ui', 'features'};

/// Violations in one file. [path] is relative to lib/, with forward slashes.
List<String> violations(String path, String source) {
  final found = <String>[];
  final layer = path.contains('/') ? path.split('/').first : 'app';
  final code = source.replaceAll(_noise, ' ');
  // Comments out, strings kept: directive URIs are strings.
  final uncommented = source.replaceAllMapped(
    _noise,
    (m) => m[1] == null ? m[0]! : ' ',
  );

  if (!_layers.contains(layer)) {
    return ['$path: unknown layer $layer/; use one of ${_layers.join(', ')}'];
  }
  if (path != 'core/clock.dart' && _wallClock.hasMatch(code)) {
    found.add('$path: reads the wall clock; use the injected Clock');
  }
  if ((layer == 'domain' || path == 'core/rupiah.dart') &&
      _double.hasMatch(code)) {
    found.add('$path: double is banned in money paths');
  }

  final uris = _directive
      .allMatches(uncommented)
      .expand((d) => _quoted.allMatches(d[0]!))
      .map((m) => m[1]!)
      // `if (dart.library.io == 'true')` carries a value, not a URI.
      .where((u) => u.endsWith('.dart') || u.contains(':'));
  for (final uri in uris) {
    if (uri.startsWith('dart:')) {
      if ((layer == 'core' || layer == 'domain') &&
          _platformLibs.contains(uri)) {
        found.add('$path: $layer/ may not import $uri');
      }
      continue;
    }

    String? target; // lib-relative path, null for an external package
    String? package;
    if (uri.startsWith('package:pulse/')) {
      target = Uri.parse(uri.substring('package:pulse/'.length))
          .normalizePath()
          .path;
    } else if (uri.startsWith('package:')) {
      package = uri.substring('package:'.length).split('/').first;
    } else {
      target = Uri.parse(path).resolve(uri).path;
    }

    if (!_allowed(layer, path, target, package)) {
      found.add('$path: $layer/ may not import $uri');
    }
  }
  return found;
}

bool _allowed(String layer, String path, String? target, String? package) {
  bool under(List<String> roots) => roots.any((r) => target!.startsWith(r));
  switch (layer) {
    case 'core':
      return target != null && under(['core/']);
    case 'domain':
      return target == null
          ? _domainPackages.contains(package)
          : under(['core/', 'domain/']);
    case 'data':
      return target == null || under(['core/', 'domain/', 'data/']);
    case 'ui':
      return target == null
          ? _uiPackages.contains(package)
          : under(['core/', 'ui/', 'domain/entities/']);
    case 'features':
      if (target == null) return !_featureBannedPackages.contains(package);
      final own = '${path.split('/').take(2).join('/')}/';
      return target == 'app/di.dart' || under(['core/', 'domain/', 'ui/', own]);
    default: // app/ and main.dart wire everything together
      return true;
  }
}

void main() {
  final found = <String>[];
  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    final path = file.path.replaceAll(r'\', '/').substring('lib/'.length);
    if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) continue;
    found.addAll(violations(path, file.readAsStringSync()));
  }
  found.forEach(stderr.writeln);
  stdout.writeln('check_imports: ${found.length} violation(s)');
  if (found.isNotEmpty) exitCode = 1;
}
