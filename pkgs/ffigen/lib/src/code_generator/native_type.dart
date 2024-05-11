// Copyright (c) 2022, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:ffigen/src/code_generator.dart';
import 'package:ffigen/src/code_generator/utils.dart';

import 'writer.dart';

enum SupportedNativeType {
  Void,
  Char,
  Int8,
  Int16,
  Int32,
  Int64,
  Uint8,
  Uint16,
  Uint32,
  Uint64,
  Float,
  Double,
  IntPtr,
  UintPtr,
}

/// Represents a primitive native type, such as float.
class NativeType extends Type {
  static const _primitives = <SupportedNativeType, NativeType>{
    SupportedNativeType.Void: NativeType._('void', '()', '()', '()', 'kk_Unit'),
    SupportedNativeType.Char: NativeType._('char', 'int8', 'int', '0', '0'),
    SupportedNativeType.Int8: NativeType._('int8_t', 'int8', 'int', '0', '0'),
    SupportedNativeType.Int16:
        NativeType._('int16_t', 'int16', 'int', '0', '0'),
    SupportedNativeType.Int32:
        NativeType._('int32_t', 'int32', 'int', '0', '0'),
    SupportedNativeType.Int64:
        NativeType._('int64_t', 'int64', 'int', '0', '0'),
    SupportedNativeType.Uint8: NativeType._('uint8_t', 'int8', 'int', '0', '0'),
    SupportedNativeType.Uint16:
        NativeType._('int16_t', 'int16', 'int', '0', '0'),
    SupportedNativeType.Uint32:
        NativeType._('int32_t', 'int32', 'int', '0', '0'),
    SupportedNativeType.Uint64:
        NativeType._('int64_t', 'int64', 'int', '0', '0'),
    SupportedNativeType.Float:
        NativeType._('float32', 'float32', 'float32', '0.0', '0.0'),
    SupportedNativeType.Double:
        NativeType._('float64', 'float64', 'float64', '0.0', '0.0'),
    SupportedNativeType.IntPtr:
        NativeType._('intptr_t', 'intptr_t', 'intptr_t', '0', '0'),
    SupportedNativeType.UintPtr:
        NativeType._('intptr_t', 'intptr_t', 'intptr_t', '0', '0'),
  };

  final String _cType;
  final String _kokaType;
  final String _externType;
  final String? _defaultValue;
  final String? _defaultCValue;

  const NativeType._(this._cType, this._externType, this._kokaType,
      this._defaultValue, this._defaultCValue);

  const NativeType.other(this._cType, this._externType, this._kokaType,
      this._defaultValue, this._defaultCValue);
  factory NativeType(SupportedNativeType type) => _primitives[type]!;

  @override
  String getRawCType(Writer w) => _cType;

  @override
  String getKokaExternType(Writer w) => _externType;

  @override
  String getKokaFFIType(Writer w) => _kokaType;

  @override
  String getKokaWrapperType(Writer w) => _kokaType;

  @override
  bool get sameExternAndFFIType => _externType == _kokaType;

  @override
  bool get sameWrapperAndExternType => _externType == _kokaType;

  @override
  bool get sameWrapperAndFFIType => true;

  @override
  String convertExternTypeToFFI(Writer w, String value) =>
      sameExternAndFFIType ? value : '$value.$_kokaType';

  @override
  String convertFFITypeToExtern(Writer w, String value) =>
      sameExternAndFFIType ? value : '$value.$_externType';

  @override
  String toString() => _cType;

  @override
  String cacheKey() => _cType;

  @override
  String? getDefaultValue(Writer w) => _defaultValue;
  @override
  String? getCDefaultValue(Writer w) => _defaultCValue;
}

class BooleanType extends NativeType {
  const BooleanType._() : super._('bool', 'bool', 'bool', 'false', 'false');
  static const _boolean = BooleanType._();
  factory BooleanType() => _boolean;

  @override
  String toString() => 'bool';

  @override
  String cacheKey() => 'bool';
}
