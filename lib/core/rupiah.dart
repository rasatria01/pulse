/// Whole rupiah. No floating point ever holds money.
extension type const Rupiah(int value) {
  static const zero = Rupiah(0);

  Rupiah operator +(Rupiah o) => Rupiah(value + o.value);
  Rupiah operator -(Rupiah o) => Rupiah(value - o.value);
  bool get isPositive => value > 0;
}
