// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:ffigen/src/code_generator.dart';

import '../strings.dart' as strings;
import 'binding_string.dart';
import 'utils.dart';
import 'writer.dart';

/// A simple Typealias, Expands to -
///
/// ```dart
/// typedef $name = $type;
/// );
/// ```
class Typealias extends BindingType {
  final Type type;
  String? _ffiDartAliasName;
  String? _dartAliasName;

  /// Creates a Typealias.
  ///
  /// If [genFfiDartType] is true, a binding is generated for the Ffi Dart type
  /// in addition to the C type. See [Type.getKokaFFIType].
  factory Typealias({
    String? usr,
    String? originalName,
    String? dartDoc,
    required String name,
    required Type type,
    bool genFfiDartType = false,
    bool isInternal = false,
  }) {
    final funcType = _getFunctionTypeFromPointer(type);
    if (funcType != null) {
      type = PointerType(NativeFunc(Typealias._(
        name: '${name}fn',
        type: funcType,
        genFfiDartType: genFfiDartType,
        isInternal: isInternal,
      )));
    }
    if ((originalName ?? name) == strings.objcInstanceType &&
        type is ObjCObjectPointer) {
      return ObjCInstanceType._(
        usr: usr,
        originalName: originalName,
        dartDoc: dartDoc,
        name: name,
        type: type,
        genFfiDartType: genFfiDartType,
        isInternal: isInternal,
      );
    }
    return Typealias._(
      usr: usr,
      originalName: originalName,
      dartDoc: dartDoc,
      name: name,
      type: type,
      genFfiDartType: genFfiDartType,
      isInternal: isInternal,
    );
  }

  Typealias._({
    super.usr,
    super.originalName,
    super.dartDoc,
    required String name,
    required this.type,
    bool genFfiDartType = false,
    super.isInternal,
  })  : _ffiDartAliasName = genFfiDartType ? 'koka-$name' : null,
        _dartAliasName = (!genFfiDartType &&
                type is! Typealias &&
                !type.sameWrapperAndFFIType)
            ? 'koka-$name'
            : null,
        super(
          name: genFfiDartType ? 'native-$name' : name,
        );

  @override
  void addDependencies(Set<Binding> dependencies) {
    if (dependencies.contains(this)) return;

    dependencies.add(this);
    type.addDependencies(dependencies);
  }

  static FunctionType? _getFunctionTypeFromPointer(Type type) {
    if (type is! PointerType) return null;
    final pointee = type.child;
    if (pointee is! NativeFunc) return null;
    return pointee.type;
  }

  @override
  BindingString toBindingString(Writer w) {
    if (_ffiDartAliasName != null) {
      _ffiDartAliasName = w.topLevelUniqueNamer.makeUnique(_ffiDartAliasName!);
    }
    if (_dartAliasName != null) {
      _dartAliasName = w.topLevelUniqueNamer.makeUnique(_dartAliasName!);
    }

    final sb = StringBuffer();
    if (dartDoc != null) {
      sb.write(makeDoc(dartDoc!));
    }
    sb.write('alias $name = ${type.getKokaFFIType(w)}\n');
    if (_ffiDartAliasName != null) {
      // sb.write('alias $_ffiDartAliasName = ${type.getFfiDartType(w)}\n');
    }
    if (_dartAliasName != null) {
      sb.write('alias $_dartAliasName = ${type.getKokaWrapperType(w)}\n');
    }
    return BindingString(
        type: BindingStringType.typeDef, string: sb.toString());
  }

  @override
  Type get typealiasType => type.typealiasType;

  @override
  bool get isIncompleteCompound => type.isIncompleteCompound;

  String getCType(Writer w) => originalName;

  @override
  String getRawCType(Writer w) => originalName;

  @override
  String getKokaExternType(Writer w) => type.getKokaExternType(w);

  @override
  String getKokaFFIType(Writer w) {
    if (type.sameExternAndFFIType) {
      return name;
    } else {
      return type.getKokaFFIType(w);
    }
  }

  @override
  String getKokaWrapperType(Writer w) {
    if (_dartAliasName != null) {
      return _dartAliasName!;
    } else if (type.sameWrapperAndExternType) {
      return getKokaFFIType(w);
    } else {
      return type.getKokaWrapperType(w);
    }
  }

  @override
  bool get sameExternAndFFIType => type.sameExternAndFFIType;

  @override
  bool get sameWrapperAndExternType => type.sameWrapperAndExternType;

  @override
  bool get sameWrapperAndFFIType => type.sameWrapperAndFFIType;

  @override
  String convertWrapperToFFIType(
    Writer w,
    String value, {
    required bool objCRetain,
    required StringBuffer additionalStatements,
    required UniqueNamer namer,
  }) =>
      type.convertWrapperToFFIType(w, value,
          objCRetain: objCRetain,
          additionalStatements: additionalStatements,
          namer: namer);

  @override
  String convertExternTypeToFFI(Writer w, String value) =>
      type.convertExternTypeToFFI(w, value);

  @override
  String convertFFITypeToExtern(Writer w, String value) =>
      type.convertFFITypeToExtern(w, value);

  @override
  String convertFFITypeToWrapper(
    Writer w,
    String value, {
    required bool objCRetain,
    String? objCEnclosingClass,
    required StringBuffer additionalStatements,
    required UniqueNamer namer,
  }) =>
      type.convertFFITypeToWrapper(w, value,
          objCRetain: objCRetain,
          objCEnclosingClass: objCEnclosingClass,
          additionalStatements: additionalStatements,
          namer: namer);

  @override
  String cacheKey() => type.cacheKey();

  @override
  String? getDefaultValue(Writer w) => type.getDefaultValue(w);

  @override
  // TODO: implement isPointerType
  bool get isPointerType => typealiasType.isPointerType;
}

/// Objective C's instancetype.
///
/// This is an alias for an NSObject* that is special cased in code generation.
/// It's only valid as the return type of a method, and always appears as the
/// enclosing class's type, even in inherited methods.
class ObjCInstanceType extends Typealias {
  ObjCInstanceType._({
    super.usr,
    super.originalName,
    super.dartDoc,
    required super.name,
    required super.type,
    super.genFfiDartType,
    super.isInternal,
  }) : super._();

  @override
  String convertWrapperToFFIType(
    Writer w,
    String value, {
    required bool objCRetain,
    String Function(String)? continuation,
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
    String Function(String)? continuation,
    required StringBuffer additionalStatements,
    required UniqueNamer namer,
  }) =>
      // objCEnclosingClass must be present, because instancetype can only
      // occur inside a class.
      ObjCInterface.generateConstructor(objCEnclosingClass!, value, objCRetain);
}
