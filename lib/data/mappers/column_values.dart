/// Column encodings shared by the mappers.
library;

DateTime instant(int epochMs) =>
    DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true);

List<String> splitAliases(String aliases) =>
    aliases.isEmpty ? const [] : aliases.split(',');
