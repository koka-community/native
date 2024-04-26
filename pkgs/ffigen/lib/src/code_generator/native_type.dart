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
    SupportedNativeType.Void: NativeType._('kk_unit_t', '()', '()', '()'),
    SupportedNativeType.Char: NativeType._('char', 'int8', 'int', '0'),
    SupportedNativeType.Int8: NativeType._('int8_t', 'int8', 'int', '0'),
    SupportedNativeType.Int16: NativeType._('int16_t', 'int16', 'int', '0'),
    SupportedNativeType.Int32: NativeType._('int32_t', 'int32', 'int', '0'),
    SupportedNativeType.Int64: NativeType._('int64_t', 'int64', 'int', '0'),
    SupportedNativeType.Uint8: NativeType._('uint8_t', 'int8', 'int', '0'),
    SupportedNativeType.Uint16: NativeType._('int16_t', 'int16', 'int', '0'),
    SupportedNativeType.Uint32: NativeType._('int32_t', 'int32', 'int', '0'),
    SupportedNativeType.Uint64: NativeType._('int64_t', 'int64', 'int', '0'),
    SupportedNativeType.Float:
        NativeType._('float32', 'float32', 'float32', '0.0'),
    SupportedNativeType.Double:
        NativeType._('float64', 'float64', 'float64', '0.0'),
    SupportedNativeType.IntPtr:
        NativeType._('intptr_t', 'intptr_t', 'intptr_t', '0'),
    SupportedNativeType.UintPtr:
        NativeType._('intptr_t', 'intptr_t', 'intptr_t', '0'),
  };

  final String _cType;
  final String _dartType;
  final String _ffiType;
  final String? _defaultValue;

  const NativeType._(
      this._cType, this._ffiType, this._dartType, this._defaultValue);

  const NativeType.other(
      this._cType, this._ffiType, this._dartType, this._defaultValue);
  factory NativeType(SupportedNativeType type) => _primitives[type]!;

  @override
  String getCType(Writer w) => _cType;

  @override
  String getFfiDartType(Writer w) => _ffiType;

  @override
  String getDartType(Writer w) => _dartType;

  @override
  bool get sameFfiDartAndCType => _cType == _ffiType;

  @override
  bool get sameDartAndCType => _cType == _dartType;

  @override
  bool get sameDartAndFfiDartType => _dartType == _ffiType;

  @override
  String convertFfiDartTypeToDartType(
    Writer w,
    String value, {
    required bool objCRetain,
    String? objCEnclosingClass,
    required StringBuffer additionalStatements,
    required UniqueNamer namer,
  }) =>
      sameDartAndFfiDartType ? value : '$value.$_dartType';

  @override
  String convertDartTypeToFfiDartType(
    Writer w,
    String value, {
    required bool objCRetain,
    required StringBuffer additionalStatements,
    required UniqueNamer namer,
  }) =>
      sameDartAndFfiDartType ? value : '$value.$_ffiType';

  @override
  String toString() => _cType;

  @override
  String cacheKey() => _cType;

  @override
  String? getDefaultValue(Writer w) => _defaultValue;
}

class BooleanType extends NativeType {
  const BooleanType._() : super._('bool', 'bool', 'bool', 'false');
  static const _boolean = BooleanType._();
  factory BooleanType() => _boolean;

  @override
  String toString() => 'bool';

  @override
  String cacheKey() => 'bool';
}
