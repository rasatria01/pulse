import 'parse_result.dart';

/// Pure and synchronous: same input and context, same output.
/// Thread C provides `parseCapture` with this signature.
typedef CaptureParser = ParseResult Function(
  String input,
  ParseContext ctx, {
  CaptureOverrides? overrides,
});
