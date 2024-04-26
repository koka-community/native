// Copyright (c) 2022, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:ffigen/src/code_generator.dart';
import 'package:ffigen/src/code_generator/utils.dart';

import 'writer.dart';

/// Represents a pointer.
class PointerType extends Type {
  final Type child;

  PointerType._(this.child);

  factory PointerType(Type child) {
    if (child == objCObjectType) {
      return ObjCObjectPointer();
    }
    return PointerType._(child);
  }

  @override
  void addDependencies(Set<Binding> dependencies) {
    child.addDependencies(dependencies);
  }

  @override
  Type get baseType => child.baseType;

  @override
  String getCType(Writer w) => '${child.getCType(w)}*';

  @override
  String getFfiDartType(Writer w) => 'intptr_t';

  @override
  String getDartType(Writer w) => baseType is NativeFunc
      ? 'intptr_t'
      : 'owned-c<${child.getFfiDartType(w)}>';

  // Both the C type and the FFI Dart type are 'Pointer<$cType>'.
  @override
  bool get sameFfiDartAndCType => false;

  @override
  bool get sameDartAndCType => false;

  @override
  bool get sameDartAndFfiDartType => baseType is NativeFunc;

  @override
  String toString() => '$child*';

  @override
  String cacheKey() => '${child.cacheKey()}*';
  @override
  String convertDartTypeToFfiDartType(
    Writer w,
    String value, {
    required bool objCRetain,
    required StringBuffer additionalStatements,
    required UniqueNamer namer,
  }) {
    final ptr = namer.makeUnique('koka-ptr');
    additionalStatements.write('with $ptr <- $value.with-ptr\n  ');
    return ptr;
  }

  @override
  String convertFfiDartTypeToDartType(Writer w, String value,
      {required bool objCRetain,
      String? objCEnclosingClass,
      required StringBuffer additionalStatements,
      required UniqueNamer namer}) {
    return '$value.c-own';
  }

  @override
  bool get isPointerType => true;
}

class BorrowedPointerType extends PointerType {
  BorrowedPointerType(Type child) : super._(child);

  @override
  String getDartType(Writer w) => 'borrowed-c<s,${child.getFfiDartType(w)}>';

  @override
  String getCType(Writer w) => '${child.getCType(w)}*';

  @override
  String getFfiDartType(Writer w) => 'intptr_t';

  @override
  String toString() => 'borrowed ${child}*';

  @override
  String convertFfiDartTypeToDartType(Writer w, String value,
      {required bool objCRetain,
      String? objCEnclosingClass,
      required StringBuffer additionalStatements,
      required UniqueNamer namer}) {
    return '$value.c-borrow';
  }

  @override
  String cacheKey() => 'borrowed ${child.cacheKey()}';
}

/// Represents a constant array, which has a fixed size.
class ConstantArray extends PointerType {
  final int length;
  final bool useArrayType;

  ConstantArray(this.length, Type child, {required this.useArrayType})
      : super._(child);

  @override
  Type get baseArrayType => child.baseArrayType;

  @override
  bool get isIncompleteCompound => baseArrayType.isIncompleteCompound;

  @override
  String toString() => '$child[$length]';

  @override
  String cacheKey() => '${child.cacheKey()}[$length]';

  @override
  String getDartType(Writer w) => 'owned-c<c-array<${child.getDartType(w)}>>';
}

/// Represents an incomplete array, which has an unknown size.
class IncompleteArray extends PointerType {
  IncompleteArray(super.child) : super._();

  @override
  Type get baseArrayType => child.baseArrayType;

  @override
  String toString() => '$child[]';

  @override
  String cacheKey() => '${child.cacheKey()}[]';

  @override
  String getDartType(Writer w) => 'owned-c<c-array<${child.getDartType(w)}>>';
}

/// A pointer to an NSObject.
class ObjCObjectPointer extends PointerType {
  factory ObjCObjectPointer() => _inst;

  static final _inst = ObjCObjectPointer._();
  ObjCObjectPointer._() : super._(objCObjectType);

  @override
  String getDartType(Writer w) => w.generateForPackageObjectiveC
      ? 'NSObject'
      : '${w.objcPkgPrefix}.NSObject';

  @override
  bool get sameDartAndCType => false;

  @override
  bool get sameDartAndFfiDartType => false;

  @override
  String convertDartTypeToFfiDartType(
    Writer w,
    String value, {
    required bool objCRetain,
    required StringBuffer additionalStatements,
    required UniqueNamer namer,
  }) =>
      ObjCInterface.generateGetId(value, objCRetain);

  @override
  String convertFfiDartTypeToDartType(
    Writer w,
    String value, {
    required bool objCRetain,
    String? objCEnclosingClass,
    required StringBuffer additionalStatements,
    required UniqueNamer namer,
  }) =>
      ObjCInterface.generateConstructor(getDartType(w), value, objCRetain);
}
