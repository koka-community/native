// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:ffigen/src/code_generator.dart';

import 'utils.dart';
import 'writer.dart';

/// Type class for return types, variable types, etc.
///
/// Implementers should extend either Type, or BindingType if the type is also a
/// binding, and override at least getCType and toString.
abstract class Type {
  const Type();

  /// Get all dependencies of this type and save them in [dependencies].
  void addDependencies(Set<Binding> dependencies) {}

  bool get isPointerType => false;

  /// Get base type for any type.
  ///
  /// E.g int** has base [Type] of int.
  /// double[2][3] has base [Type] of double.
  Type get baseType => this;

  /// Get base Array type.
  ///
  /// Returns itself if it's not an Array Type.
  Type get baseArrayType => this;

  /// Get base typealias type.
  ///
  /// Returns itself if it's not a Typealias.
  Type get typealiasType => this;

  /// Returns true if the type is a [Compound] and is incomplete.
  bool get isIncompleteCompound => false;

  /// Return the type that should be casted in the function (C) signature - should be exactly equal to the C type.
  String getRawCType(Writer w) => throw 'No mapping for type: $this';

  /// Returns the raw extern ffi definition type. This is the basic bool, sized int or intptr_t type that can be cast directly to the C signature
  String getKokaExternType(Writer w) => getRawCType(w);

  /// Returns the simply wrapped type (e.g. c-pointer<type> for pointers, c-array<type> for arrays, what about ints?)
  String getKokaFFIType(Writer w) => getKokaExternType(w);

  /// Returns the user type of the Type. This is the type that is presented to
  /// users by the ffigened API to users. For C bindings this is always the same
  /// as getKokaFFIType. For ObjC bindings this refers to the wrapper object.
  String getKokaWrapperType(Writer w) => getKokaFFIType(w);

  /// Returns whether the FFI koka type and extern koka type string are same.
  bool get sameExternAndFFIType;

  /// Returns whether the Wrapper type and extern koka type string are same.
  bool get sameWrapperAndExternType => sameExternAndFFIType;

  /// Returns whether the Wrapper type and FFI koka type string are same.
  bool get sameWrapperAndFFIType => true;

  String convertFFITypeToExtern(Writer w, String value) => value;
  String convertExternTypeToFFI(Writer w, String value) => value;

  /// Returns generated Dart code that converts the given value from its
  /// DartType to its FfiDartType.
  ///
  /// [value] is the value to be converted. If [objCRetain] is true, the ObjC
  /// object will be reained (ref count incremented) during conversion.
  String convertWrapperToFFIType(
    Writer w,
    String value, {
    required bool objCRetain,
    required StringBuffer additionalStatements,
    required UniqueNamer namer,
  }) =>
      value;

  /// Returns generated Dart code that converts the given value from its
  /// FfiDartType to its DartType.
  ///
  /// [value] is the value to be converted. If [objCRetain] is true, the ObjC wrapper object
  /// will retain (ref count increment) the wrapped object pointer. If this
  /// conversion is occuring in the context of an ObjC class, then
  /// [objCEnclosingClass] should be the name of the Dart wrapper class (this is
  /// used by instancetype).
  String convertFFITypeToWrapper(
    Writer w,
    String value, {
    required bool objCRetain,
    String? objCEnclosingClass,
    required StringBuffer additionalStatements,
    required UniqueNamer namer,
  }) =>
      value;

  /// Returns a human readable string representation of the Type. This is mostly
  /// just for debugging, but it may also be used for non-functional code (eg to
  /// name a variable or type in generated code).
  @override
  String toString();

  /// Cache key used in various places to dedupe Types. By default this is just
  /// the hash of the Type, but in many cases this does not dedupe sufficiently.
  /// So Types that may be duplicated should override this to return a more
  /// specific key. Types that are already deduped don't need to override this.
  /// toString() is not a valid cache key as there may be name collisions.
  String cacheKey() => hashCode.toRadixString(36);

  /// Returns a string of code that creates a default value for this type. For
  /// example, for int types this returns the string '0'. A null return means
  /// that default values aren't supported for this type, eg void.
  String? getDefaultValue(Writer w) => null;

  Set<String> get convertExternToFFIEffects => {};
}

/// Base class for all Type bindings.
///
/// Since Dart doesn't have multiple inheritance, this type exists so that we
/// don't have to reimplement the default methods in all the classes that want
/// to extend both NoLookUpBinding and Type.
abstract class BindingType extends NoLookUpBinding implements Type {
  BindingType({
    super.usr,
    super.originalName,
    required super.name,
    super.dartDoc,
    super.isInternal,
  });

  @override
  bool get isPointerType => false;

  @override
  Type get baseType => this;

  @override
  Type get baseArrayType => this;

  @override
  Type get typealiasType => this;

  @override
  bool get isIncompleteCompound => false;

  @override
  String getRawCType(Writer w) => originalName;

  @override
  String getKokaFFIType(Writer w) => getKokaExternType(w);

  @override
  String getKokaWrapperType(Writer w) => getKokaFFIType(w);

  @override
  bool get sameWrapperAndExternType => sameExternAndFFIType;

  @override
  bool get sameWrapperAndFFIType => true;

  @override
  String convertWrapperToFFIType(
    Writer w,
    String value, {
    required bool objCRetain,
    required StringBuffer additionalStatements,
    required UniqueNamer namer,
  }) =>
      value;

  @override
  String convertFFITypeToWrapper(
    Writer w,
    String value, {
    required bool objCRetain,
    String? objCEnclosingClass,
    required StringBuffer additionalStatements,
    required UniqueNamer namer,
  }) =>
      value;

  @override
  String convertFFITypeToExtern(Writer w, String value) => value;
  @override
  String convertExternTypeToFFI(Writer w, String value) => value;
  @override
  String toString() => originalName;

  @override
  String cacheKey() => hashCode.toRadixString(36);

  @override
  String? getDefaultValue(Writer w) => null;

  @override
  Set<String> get convertExternToFFIEffects => {};
}

/// Represents an unimplemented type. Used as a marker, so that declarations
/// having these can exclude them.
class UnimplementedType extends Type {
  String reason;
  UnimplementedType(this.reason);

  @override
  String toString() => '(Unimplemented: $reason)';

  @override
  bool get sameExternAndFFIType => true;
}
