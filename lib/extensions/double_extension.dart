extension DoubleExtension on double {
  String toTrimmedPriceString({int fractionDigits = 2}) {
    final fixedValue = toStringAsFixed(fractionDigits);
    if (!fixedValue.contains('.')) {
      return fixedValue;
    }
    return fixedValue
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
