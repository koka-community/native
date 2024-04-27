// Copyright (c) 2022, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:ffigen/src/code_generator.dart';
import 'package:ffigen/src/code_generator/utils.dart';

import 'writer.dart';

/// Represents a function type.
class FunctionType extends Type {
  final Type returnType;
  final List<Parameter> parameters;
  final List<Parameter> varArgParameters;

  /// Get all the parameters for generating the dart type. This includes both
  /// [parameters] and [varArgParameters].
  List<Parameter> get dartTypeParameters => parameters + varArgParameters;

  FunctionType({
    required this.returnType,
    required this.parameters,
    this.varArgParameters = const [],
  });

  String _getTypeImpl(
      bool writeArgumentNames, String Function(Type) typeToString,
      {String? varArgWrapper}) {
    final params = varArgWrapper != null ? parameters : dartTypeParameters;
    String? varArgPack;
    if (varArgWrapper != null && varArgParameters.isNotEmpty) {
      final varArgPackBuf = StringBuffer();
      varArgPackBuf.write("$varArgWrapper<(");
      varArgPackBuf.write((varArgParameters).map<String>((p) {
        return '${writeArgumentNames ? p.name.isEmpty ? '' : '${p.name} : ' : ""}${typeToString(p.type)}';
      }).join(', '));
      varArgPackBuf.write(")>");
      varArgPack = varArgPackBuf.toString();
    }

    // Write return Type.
    final sb = StringBuffer();

    // Write Function.
    sb.write('((');
    sb.write([
      ...params.map<String>((p) {
        return '${writeArgumentNames ? p.name.isEmpty ? '' : '${p.name} : ' : ""}${typeToString(p.type)}';
      }),
      if (varArgPack != null) varArgPack,
    ].join(', '));
    sb.write(')');
    sb.write(' -> ${typeToString(returnType)})');

    return sb.toString();
  }

  @override
  String getKokaExternType(Writer w, {bool writeArgumentNames = true}) =>
      _getTypeImpl(writeArgumentNames, (Type t) => t.getKokaExternType(w),
          varArgWrapper: '${w.ffiLibraryPrefix}.VarArgs');

  @override
  String getKokaFFIType(Writer w, {bool writeArgumentNames = true}) =>
      _getTypeImpl(writeArgumentNames, (Type t) => t.getKokaFFIType(w));

  @override
  String getKokaWrapperType(Writer w, {bool writeArgumentNames = true}) =>
      _getTypeImpl(writeArgumentNames, (Type t) => t.getKokaWrapperType(w));

  @override
  bool get sameExternAndFFIType =>
      returnType.sameExternAndFFIType &&
      dartTypeParameters.every((p) => p.type.sameExternAndFFIType);

  @override
  bool get sameWrapperAndExternType =>
      returnType.sameWrapperAndExternType &&
      dartTypeParameters.every((p) => p.type.sameWrapperAndExternType);

  @override
  bool get sameWrapperAndFFIType =>
      returnType.sameWrapperAndFFIType &&
      dartTypeParameters.every((p) => p.type.sameWrapperAndFFIType);

  @override
  String toString() => _getTypeImpl(false, (Type t) => t.toString());

  @override
  String cacheKey() => _getTypeImpl(false, (Type t) => t.cacheKey());

  @override
  void addDependencies(Set<Binding> dependencies) {
    returnType.addDependencies(dependencies);
    for (final p in parameters) {
      p.type.addDependencies(dependencies);
    }
  }

  void addParameterNames(List<String> names) {
    if (names.length != parameters.length) {
      return;
    }
    final paramNamer = UniqueNamer({});
    for (int i = 0; i < parameters.length; i++) {
      final finalName = paramNamer.makeUnique(names[i]);
      parameters[i] = Parameter(
        type: parameters[i].type,
        originalName: names[i],
        name: finalName,
      );
    }
  }
}

/// Represents a NativeFunction<Function>.
class NativeFunc extends Type {
  // Either a FunctionType or a Typealias of a FunctionType.
  final Type _type;

  NativeFunc(this._type) {
    assert(_type is FunctionType || _type is Typealias);
  }

  FunctionType get type {
    if (_type is Typealias) {
      return _type.typealiasType as FunctionType;
    }
    return _type as FunctionType;
  }

  @override
  void addDependencies(Set<Binding> dependencies) {
    _type.addDependencies(dependencies);
  }

  @override
  String getKokaExternType(Writer w) => 'intptr_t';

  @override
  String getKokaFFIType(Writer w) => 'intptr_t';

  @override
  String getKokaWrapperType(Writer w) => 'intptr_t';

  @override
  bool get sameExternAndFFIType => true;

  @override
  bool get sameWrapperAndExternType => true;

  @override
  bool get sameWrapperAndFFIType => true;

  @override
  String toString() => '${_type.toString()}';

  @override
  String cacheKey() => '${_type.cacheKey()}';
}
