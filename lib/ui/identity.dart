import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// The identity colour for a stored `wallets.color` / `categories.color` ARGB
/// int. A value that isn't one of the ten (an import) shows as slate.
Color identityColor(int argb) => PulseIdentity.all.firstWhere(
  (c) => c.toARGB32() == argb,
  orElse: () => PulseIdentity.slate,
);
