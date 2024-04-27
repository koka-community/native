// Copyright (c) 2023, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:ffigen/src/code_generator.dart';
import 'package:ffigen/src/code_generator/utils.dart';

import 'writer.dart';

/// An ObjC type annotated with nullable. Eg:
/// +(nullable NSObject*) methodWithNullableResult;
class ObjCNullable extends Type {
  Type child;

  ObjCNullable(this.child) {
    assert(isSupported(child));
  }

  static bool isSupported(Type type) =>
      type is ObjCInterface ||
      type is ObjCBlock ||
      type is ObjCObjectPointer ||
      type is ObjCInstanceType;

  @override
  void addDependencies(Set<Binding> dependencies) {
    child.addDependencies(dependencies);
  }

  @override
  Type get baseType => child.baseType;

  @override
  String getKokaExternType(Writer w) => child.getKokaExternType(w);

  @override
  String getKokaFFIType(Writer w) => child.getKokaFFIType(w);

  @override
  String getKokaWrapperType(Writer w) => '${child.getKokaWrapperType(w)}?';

  @override
  bool get sameExternAndFFIType => child.sameExternAndFFIType;

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
  }) {
    // This is a bit of a hack, but works for all the types that are allowed to
    // be a child type. If we add more allowed child types, we may have to start
    // special casing each type. Turns value._id into value?._id ?? nullptr.
    final convertedValue = child.convertWrapperToFFIType(
      w,
      '$value?',
      objCRetain: objCRetain,
      additionalStatements: additionalStatements,
      namer: namer,
    );
    return '$convertedValue ?? ${w.ffiLibraryPrefix}.nullptr';
  }

  @override
  String convertFFITypeToWrapper(
    Writer w,
    String value, {
    required bool objCRetain,
    String? objCEnclosingClass,
    required StringBuffer additionalStatements,
    required UniqueNamer namer,
  }) {
    // All currently supported child types have a Pointer as their FfiDartType.
    final convertedValue = child.convertFFITypeToWrapper(
      w,
      value,
      objCRetain: objCRetain,
      objCEnclosingClass: objCEnclosingClass,
      additionalStatements: additionalStatements,
      namer: namer,
    );
    return '$value.address == 0 ? null : $convertedValue';
  }

  @override
  String toString() => '$child?';

  @override
  String cacheKey() => '${child.cacheKey()}?';
}
