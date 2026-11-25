import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/rupiah.dart';

part 'wallet.freezed.dart';

enum WalletKind { cash, bank, ewallet, other }

@freezed
abstract class Wallet with _$Wallet {
  const factory Wallet({
    required String id,
    required String name,
    required String slug,
    @Default(<String>[]) List<String> aliases,
    required WalletKind kind,
    required Rupiah initialBalance,
    required int color, // ARGB
    required String icon,
    required bool includeInTotal,
    required bool isDefault,
    required bool isArchived,
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Wallet;
}

/// Parser snapshot.
@freezed
abstract class WalletRef with _$WalletRef {
  const factory WalletRef({
    required String id,
    required String slug,
    @Default(<String>[]) List<String> aliases,
    required bool isDefault,
    required bool isArchived,
  }) = _WalletRef;
}

@freezed
abstract class WalletBalance with _$WalletBalance {
  const factory WalletBalance({
    required Wallet wallet,
    required Rupiah balance,
  }) = _WalletBalance;
}

@freezed
abstract class WalletInput with _$WalletInput {
  const factory WalletInput({
    required String name,
    required String slug,
    @Default(<String>[]) List<String> aliases,
    required WalletKind kind,
    @Default(Rupiah.zero) Rupiah initialBalance,
    required int color,
    required String icon,
    @Default(true) bool includeInTotal,
    @Default(false) bool isDefault,
    @Default(0) int sortOrder,
  }) = _WalletInput;
}

/// Null field = unchanged. Default and archived have their own methods.
@freezed
abstract class WalletPatch with _$WalletPatch {
  const factory WalletPatch({
    String? name,
    String? slug,
    List<String>? aliases,
    WalletKind? kind,
    Rupiah? initialBalance,
    int? color,
    String? icon,
    bool? includeInTotal,
    int? sortOrder,
  }) = _WalletPatch;
}
