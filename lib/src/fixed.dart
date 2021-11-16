import 'dart:math';

import 'package:decimal/decimal.dart';

import 'fixed_decoder.dart';
import 'fixed_encoder.dart';

/// Represents a fixed scale decimal no.
/// The value is stored using the minor units
/// e.g.
/// If a Fixed no. has a scale of 2 then
/// 1 is stored as 100.
class Fixed implements Comparable<Fixed> {
  // The value
  late final Decimal value;

  late final BigInt minorUnits = (value * Decimal.ten.pow(scale)).toBigInt();

  /// The scale to which we store the amount
  /// A scale of 2 means we store the value to
  /// two decimal places.
  final int scale;

  /// Parses [amount] for a decimal value
  /// using [pattern] to interpret the string.
  ///
  /// The [scale] expects the number of decimal
  /// places to be retained.
  /// If [scale] < 0 then a FixedException will be thrown.
  static Fixed parse(
    String amount, {
    String pattern = '#.#',
    int scale = 2,
    bool invertSeparator = false,
  }) {
    _checkScale(scale);
    final decoder = FixedDecoder(
      pattern: pattern,
      thousandSeparator: invertSeparator ? '.' : ',',
      decimalSeparator: invertSeparator ? ',' : '.',
      scale: scale,
    );
    return Fixed.fromDecimal(decoder.decode(amount), scale: scale);
  }

  /// Fixed a new fixed value from an existing one
  /// adjusting the scale.
  Fixed(Fixed fixed, {this.scale = 2}) {
    _checkScale(scale);
    value =
        _rescale(fixed.value, existingScale: fixed.scale, targetScale: scale);
  }

  Decimal _rescale(
    Decimal value, {
    required int existingScale,
    required int targetScale,
  }) {
    if (existingScale <= targetScale) {
      // no precision lost
      return value;
    }
    if (value.hasFinitePrecision && value.scale <= targetScale) {
      // no precision lost
      return value;
    }
    var coef = Decimal.ten.pow(targetScale);
    return (value * coef).truncate() / coef;
  }

  /// Creates a Fixed scale value from decimal
  /// or integer value and stores the value with
  /// a the given [scale].
  /// ```dart
  /// final value = Fixed.from(1.2345, scale: 2);
  /// print(value) -> 1.23
  Fixed.from(num amount, {this.scale = 2}) {
    _checkScale(scale);

    final decoder = FixedDecoder(
      scale: scale,
      pattern: '#.#',
      thousandSeparator: ',',
      decimalSeparator: '.',
    );

    value = decoder.decode(amount.toStringAsFixed(scale));
  }

  /// Creates Fixed scale decimal from [minorUnits].
  ///
  /// e.g.
  /// ```dart
  /// final fixed = Fixed.fromMinorUnits(100, scale: 2)
  /// print(fixed) : 1.00
  /// ```
  Fixed.fromMinorUnits(int minorUnits, {this.scale = 2}) {
    _checkScale(scale);
    value = Decimal.fromInt(minorUnits) / Decimal.ten.pow(scale);
  }
  // Fixed.fromParts(int integerPart, int decimalPart, {this.scale = 2}) {
  //   _checkScale();
  //   minorUnits = integerPart * pow(10, scale) + (decimalPart * );
  // }

  /// Creates a fixed scale decimal from [minorUnits]
  Fixed.fromBigInt(BigInt minorUnits, {this.scale = 2}) {
    _checkScale(scale);
    value = Decimal.fromBigInt(minorUnits) / Decimal.ten.pow(scale);
  }

  /// Creates a fixed scale decimal from [minorUnits]
  Fixed.fromDecimal(Decimal value, {this.scale = 2}) {
    _checkScale(scale);
    this.value =
        _rescale(value, existingScale: value.scale, targetScale: scale);
  }

  static void _checkScale(int scale) {
    if (scale < 0) {
      throw FixedException('A negative scale of $scale was passed. '
          'The scale must be >= 0.');
    }
  }

  //String toString() => FixedPresionEncoder

  BigInt get scaleFactor => BigInt.from(10).pow(scale);

  /// The component of the number before the decimal point
  BigInt get integerPart => value.toBigInt();

  /// The component of the number after the decimal point.
  BigInt get decimalPart => (minorUnits - integerPart * scaleFactor).abs();

  /// returns true of the value of this [MinorUnit] is zero.
  bool get isZero => value == Decimal.zero;

  /// returns true of the value of this [MinorUnit] is negative.
  bool get isNegative => value < Decimal.zero;

  /// returns true of the value of this [MinorUnit] is positive.
  bool get isPositive => value > Decimal.zero;

  /// Two [Fixed] instances are the same if they have
  /// the same minorUnits and the same scale.
  @override
  int compareTo(Fixed other) {
    if (value == other.value) {
      return scale.compareTo(other.scale);
    } else {
      return value.compareTo(other.value);
    }
  }

  @override
  int get hashCode => value.hashCode + scale.hashCode;

  /// Two Fixed values are considered equal if they have
  /// the same numeric amount.
  /// We convert the minorUnits to the same scale in
  /// order to do the comparision.
  @override
  bool operator ==(covariant Fixed other) => value == other.value;

  /// less than operator
  bool operator <(Fixed other) => value < other.value;

  /// less than or equal operator
  bool operator <=(Fixed other) => value <= other.value;

  /// greater than operator
  bool operator >(Fixed other) => value > other.value;

  /// greater than or equal operator
  bool operator >=(Fixed other) => value >= other.value;

  /// Arithmetic

  /// add operator
  /// The resulting [scale] is the larger scale of the two operands.
  Fixed operator +(Fixed other) =>
      Fixed.fromDecimal(value + other.value, scale: max(scale, other.scale));

  /// unary minus operator.
  Fixed operator -() => Fixed.fromDecimal(-value, scale: scale);

  /// subtract operator
  Fixed operator -(Fixed other) =>
      Fixed.fromDecimal(value - other.value, scale: max(scale, other.scale));

  /// multiplication operator.
  /// The scale in the result is the sum or the scale of the two
  /// operands.
  Fixed operator *(Fixed other) =>
      Fixed.fromDecimal(value * other.value, scale: scale + other.scale);

  /// Division operator.
  Fixed operator /(Fixed other) =>
      Fixed.fromDecimal(value / other.value, scale: max(scale, other.scale));

  Fixed multiply(num multiplier) {
    if (multiplier is int) {
      return Fixed.fromDecimal(value * Decimal.fromInt(multiplier),
          scale: scale);
    }

    if (multiplier is double) {
      const floatingDecimalFactor = 1e14;
      final decimalFactor = BigInt.from(100000000000000); // 1e14
      final roundingFactor = BigInt.from(50000000000000); // 5 * 1e14

      final product = minorUnits *
          BigInt.from((multiplier.abs() * floatingDecimalFactor).round());

      var result = product ~/ decimalFactor;
      if (product.remainder(decimalFactor) >= roundingFactor) {
        result += BigInt.one;
      }
      if (multiplier.isNegative) {
        result *= -BigInt.one;
      }

      return Fixed.fromBigInt(result);
    }
    throw UnsupportedError(
        'Unsupported type of multiplier: "${multiplier.runtimeType}", '
        '(int or double are expected)');
  }

  Fixed divide(num divisor) {
    return this * Fixed.from(1.0 / divisor.toDouble());
  }

  ///  Allocation
  List<Fixed> allocationAccordingTo(List<int> ratios) {
    if (ratios.isEmpty) {
      throw ArgumentError.value(ratios, 'ratios',
          'List of ratios must not be empty, cannot allocate to nothing.');
    }

    return _doAllocationAccordingTo(ratios.map((ratio) {
      if (ratio < 0) {
        throw ArgumentError.value(
            ratios, 'ratios', 'Ratio must not be negative.');
      }

      return BigInt.from(ratio);
    }).toList());
  }

  List<Fixed> _doAllocationAccordingTo(List<BigInt> ratios) {
    final totalVolume = ratios.reduce((a, b) => a + b);

    if (totalVolume == BigInt.zero) {
      throw ArgumentError('Sum of ratios must be greater than zero, '
          'cannot allocate to nothing.');
    }

    final absoluteValue = minorUnits.abs();
    var remainder = absoluteValue;

    final shares = ratios.map((ratio) {
      final share = absoluteValue * ratio ~/ totalVolume;
      remainder -= share;

      return share;
    }).toList();

    for (var i = 0; remainder > BigInt.zero && i < shares.length; ++i) {
      if (ratios[i] > BigInt.zero) {
        shares[i] += BigInt.one;
        remainder -= BigInt.one;
      }
    }

    return shares
        .map((share) => Fixed.fromBigInt(minorUnits.isNegative ? -share : share,
            scale: scale))
        .toList();
  }

  ///
  /// Type Conversion **********************************************************
  ///

  Decimal toDecimal() => value;

  @override
  String toString() {
    final String pattern;
    if (scale == 0) {
      pattern = '#';
    } else {
      pattern = '#.${'#' * scale}';
    }
    final encoder =
        FixedEncoder(pattern, decimalSeparator: '.', thousandSeparator: ',');

    return encoder.encode(this);
  }

  String format(String pattern, {bool invertSeparators = false}) {
    if (!invertSeparators) {
      return FixedEncoder(pattern,
              decimalSeparator: '.', thousandSeparator: ',')
          .encode(this);
    } else {
      return FixedEncoder(pattern,
              decimalSeparator: ',', thousandSeparator: '.')
          .encode(this);
    }
  }
}

class FixedException implements Exception {
  FixedException(this.message);

  String message;

  @override
  String toString() => message;
}
