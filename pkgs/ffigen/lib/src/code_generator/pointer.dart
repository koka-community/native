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
  String getRawCType(Writer w) {
    if (child is NativeFunc) {
      return child.getRawCType(w);
    }
    if (child.getRawCType(w) == 'intptr_t') {
      return 'intptr_t';
    } else {
      return '${child.getRawCType(w)}*';
    }
  }

  @override
  String getKokaExternType(Writer w) => 'intptr_t';

  @override
  String getKokaFFIType(Writer w) => 'c-pointer<${child.getKokaFFIType(w)}>';

  @override
  String getKokaWrapperType(Writer w) =>
      'c-pointer<${child.getKokaFFIType(w)}>';

  // Both the C type and the FFI Dart type are 'Pointer<$cType>'.
  @override
  bool get sameExternAndFFIType => false;

  @override
  bool get sameWrapperAndExternType => false;

  @override
  bool get sameWrapperAndFFIType => true;

  @override
  String toString() => '$child*';

  @override
  String cacheKey() => '${child.cacheKey()}*';

  @override
  String convertWrapperToFFIType(
    Writer w,
    String value, {
    required bool objCRetain,
    required StringBuffer additionalStatements,
    required UniqueNamer namer,
  }) {
    return '$value.ptr';
  }

  @override
  String convertFFITypeToExtern(Writer w, String value) {
    return '$value.ptr';
  }

  @override
  String convertFFITypeToWrapper(Writer w, String value,
      {required bool objCRetain,
      String? objCEnclosingClass,
      required StringBuffer additionalStatements,
      required UniqueNamer namer}) {
    return 'C-pointer($value)';
  }

  @override
  String convertExternTypeToFFI(Writer w, String value) {
    return 'C-pointer($value)';
  }

  @override
  bool get isPointerType => true;
}

class BorrowedPointerType extends PointerType {
  BorrowedPointerType(Type child) : super._(child);

  @override
  String getKokaWrapperType(Writer w) =>
      'borrowed-c<s,${child.getKokaFFIType(w)}>';

  @override
  String getKokaExternType(Writer w) => '${child.getKokaExternType(w)}*';

  @override
  String getKokaFFIType(Writer w) => 'intptr_t';

  @override
  String toString() => 'borrowed ${child}*';

  @override
  String convertFFITypeToWrapper(Writer w, String value,
      {required bool objCRetain,
      String? objCEnclosingClass,
      required StringBuffer additionalStatements,
      required UniqueNamer namer}) {
    return '$value.c-borrow';
  }

  @override
  String cacheKey() => 'borrowed ${child.cacheKey()}';
}

class OwnedPointerType extends PointerType {
  OwnedPointerType(Type child) : super._(child);

  @override
  String getKokaWrapperType(Writer w) => 'owned-c<${child.getKokaFFIType(w)}>';

  @override
  String getKokaExternType(Writer w) => '${child.getKokaExternType(w)}*';

  @override
  String getKokaFFIType(Writer w) => 'intptr_t';

  @override
  String toString() => 'owned ${child}*';

  @override
  String convertFFITypeToWrapper(Writer w, String value,
      {required bool objCRetain,
      String? objCEnclosingClass,
      required StringBuffer additionalStatements,
      required UniqueNamer namer}) {
    return '$value.c-own';
  }

  @override
  String cacheKey() => 'owned ${child.cacheKey()}';
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
  String getKokaFFIType(Writer w) => 'c-array<${child.getKokaFFIType(w)}>';
  @override
  String getKokaWrapperType(Writer w) => 'c-array<${child.getKokaFFIType(w)}>';
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
  String getKokaFFIType(Writer w) => 'c-array<${child.getKokaFFIType(w)}>';
  @override
  String getKokaWrapperType(Writer w) => 'c-array<${child.getKokaFFIType(w)}>';
}

/// A pointer to an NSObject.
class ObjCObjectPointer extends PointerType {
  factory ObjCObjectPointer() => _inst;

  static final _inst = ObjCObjectPointer._();
  ObjCObjectPointer._() : super._(objCObjectType);

  @override
  String getKokaWrapperType(Writer w) => w.generateForPackageObjectiveC
      ? 'NSObject'
      : '${w.objcPkgPrefix}.NSObject';

  @override
  bool get sameWrapperAndExternType => false;

  @override
  bool get sameWrapperAndFFIType => false;

  @override
  String convertWrapperToFFIType(
    Writer w,
    String value, {
    required bool objCRetain,
    required StringBuffer additionalStatements,
    required UniqueNamer namer,
  }) =>
      ObjCInterface.generateGetId(value, objCRetain);

  @override
  String convertFFITypeToWrapper(
    Writer w,
    String value, {
    required bool objCRetain,
    String? objCEnclosingClass,
    required StringBuffer additionalStatements,
    required UniqueNamer namer,
  }) =>
      ObjCInterface.generateConstructor(
          getKokaWrapperType(w), value, objCRetain);
}
