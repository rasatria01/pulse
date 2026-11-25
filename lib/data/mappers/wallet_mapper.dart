import '../../core/rupiah.dart';
import '../../domain/entities/wallet.dart';
import '../db/app_database.dart';
import 'column_values.dart';

extension WalletRowMapper on WalletRow {
  Wallet toEntity() => Wallet(
    id: id,
    name: name,
    slug: slug,
    aliases: splitAliases(aliases),
    kind: WalletKind.values.byName(kind),
    initialBalance: Rupiah(initialBalance),
    color: color,
    icon: icon,
    includeInTotal: includeInTotal == 1,
    isDefault: isDefault == 1,
    isArchived: isArchived == 1,
    sortOrder: sortOrder,
    createdAt: instant(createdAt),
    updatedAt: instant(updatedAt),
  );

  WalletRef toRef() => WalletRef(
    id: id,
    slug: slug,
    aliases: splitAliases(aliases),
    isDefault: isDefault == 1,
    isArchived: isArchived == 1,
  );
}
