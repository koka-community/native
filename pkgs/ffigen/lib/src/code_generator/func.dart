// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:ffigen/src/code_generator.dart';
import 'package:ffigen/src/config_provider/config_types.dart';
import 'package:logging/logging.dart';

import 'binding_string.dart';
import 'utils.dart';
import 'writer.dart';

final _logger = Logger('ffigen.code_generator.func');

/// A binding for C function.
///
/// For example, take the following C function.
///
/// ```c
/// int sum(int a, int b);
/// ```
///
/// The generated Dart code for this function (without `FfiNative`) is as follows.
///
/// ```dart
/// int sum(int a, int b) {
///   return _sum(a, b);
/// }
///
/// final _dart_sum _sum = _dylib.lookupFunction<_c_sum, _dart_sum>('sum');
///
/// typedef _c_sum = ffi.Int32 Function(ffi.Int32 a, ffi.Int32 b);
///
/// typedef _dart_sum = int Function(int a, int b);
/// ```
///
/// When using `Native`, the code is as follows.
///
/// ```dart
/// @ffi.Native<ffi.Int32 Function(ffi.Int32 a, ffi.Int32 b)>('sum')
/// external int sum(int a, int b);
/// ```
class Func extends LookUpBinding {
  final FunctionType functionType;
  final bool exposeSymbolAddress;
  final bool exposeFunctionTypedefs;
  final bool isLeaf;
  final bool objCReturnsRetained;
  final FfiNativeConfig ffiNativeConfig;
  late final String funcPointerName;

  /// Contains typealias for function type if [exposeFunctionTypedefs] is true.
  Typealias? _exposedFunctionTypealias;

  /// [originalName] is looked up in dynamic library, if not
  /// provided, takes the value of [name].
  Func({
    super.usr,
    required String name,
    super.originalName,
    super.dartDoc,
    required Type returnType,
    List<Parameter>? parameters,
    List<Parameter>? varArgParameters,
    this.exposeSymbolAddress = false,
    this.exposeFunctionTypedefs = false,
    this.isLeaf = false,
    this.objCReturnsRetained = false,
    super.isInternal,
    this.ffiNativeConfig = const FfiNativeConfig(enabled: false),
  })  : functionType = FunctionType(
          returnType: returnType,
          parameters: parameters ?? const [],
          varArgParameters: varArgParameters ?? const [],
        ),
        super(
          name: name,
        ) {
    for (var i = 0; i < functionType.parameters.length; i++) {
      if (functionType.parameters[i].name.trim() == '') {
        functionType.parameters[i].name = 'arg$i';
      }
    }

    // Get function name with first letter in upper case.
    final upperCaseName = name[0].toUpperCase() + name.substring(1);
    _exposedFunctionTypealias = Typealias(
      name: upperCaseName,
      type: functionType,
      genFfiDartType: true,
      isInternal: true,
    );
  }

  @override
  BindingString toBindingString(Writer w) {
    final s = StringBuffer();
    final enclosingFuncName = name;
    if (functionType.returnType is Compound ||
        functionType.parameters.any((p) => p is Compound)) {
      _logger.warning(
          'Cannot generate function $enclosingFuncName with compound types passed by value');
      return BindingString(type: BindingStringType.constant, string: "");
    }

    if (dartDoc != null) {
      s.write(makeDoc(dartDoc!));
    }
    // Resolve name conflicts in function parameter names.
    final paramNamer = UniqueNamer({});
    for (final p in functionType.dartTypeParameters) {
      p.name = paramNamer.makeUnique(p.name);
    }

    final cType = _exposedFunctionTypealias?.getKokaExternType(w) ??
        functionType.getKokaExternType(w, writeArgumentNames: false);
    // final dartType = _exposedFunctionTypealias?.getFfiDartType(w) ??
    //     functionType.getFfiDartType(w, writeArgumentNames: false);
    final needsWrapper = !functionType.sameWrapperAndFFIType && !isInternal;
    // print("Needs wrapper $needsWrapper");
    final funcVarName =
        'external/$enclosingFuncName'; // w.wrapperLevelUniqueNamer.makeUnique('_$name');
    final externReturnType = functionType.returnType.getKokaExternType(w);
    final externArgDeclString = functionType.dartTypeParameters
        .map((p) => '^${p.name}: ${p.type.getKokaExternType(w)}')
        .join(', ');
    final ffiArgs = functionType.dartTypeParameters
        .mapIndexed((i, p) => '(${p.type.getRawCType(w)})#${i + 1}')
        .join(', ');
    late final String dartReturnType;
    late final String dartArgDeclString;

    late final String funcImplCall;
    final strBuff = StringBuffer();
    if (needsWrapper) {
      dartReturnType = functionType.returnType.getKokaWrapperType(w);
      dartArgDeclString = functionType.dartTypeParameters
          .map((p) => '^${p.name}: ${p.type.getKokaWrapperType(w)}')
          .join(', ');
      final namer = UniqueNamer({});
      final argString = functionType.dartTypeParameters
          .map((p) => p.type.convertWrapperToFFIType(w, p.name,
              objCRetain: false, additionalStatements: strBuff, namer: namer))
          .join(', ');
      funcImplCall = functionType.returnType.convertFFITypeToWrapper(
          w, '$funcVarName($argString)',
          objCRetain: !objCReturnsRetained,
          additionalStatements: strBuff,
          namer: namer);
    } else {
      dartReturnType = externReturnType;
      dartArgDeclString = externArgDeclString;
      final argString =
          functionType.dartTypeParameters.map((p) => '${p.name},\n').join('');
      funcImplCall = '$funcVarName($argString)';
    }

    if (ffiNativeConfig.enabled) {
      final nativeFuncName = enclosingFuncName;
//       s.write('''
// ${makeNativeAnnotation(
//         w,
//         nativeType: cType,
//         dartName: nativeFuncName,
//         nativeSymbolName: originalName,
//         isLeaf: isLeaf,
//       )}

      s.writeln(
          '''pub extern external/$nativeFuncName($externArgDeclString): $externReturnType
  c inline "$originalName($ffiArgs)"\n''');
      if (needsWrapper) {
        // print(
        //     "Wrapper ${nativeFuncName} ${functionType.parameters.map((e) => e.type.runtimeType)} ${functionType.returnType}");
        s.writeln('''
pub fun wrapper/$nativeFuncName($dartArgDeclString): $dartReturnType
  ${strBuff.toString()}$funcImplCall\n''');
      }

      if (exposeSymbolAddress) {
        // Add to SymbolAddress in writer.
        w.symbolAddressWriter.addNativeSymbol(
          type: 'owned-c<NativeFunction<$cType>>',
          name: name,
        );
      }
    } else {
      funcPointerName = w.wrapperLevelUniqueNamer.makeUnique('${name}ptr');

      final funcTypeName = w.wrapperLevelUniqueNamer.makeUnique('${name}fn');
      // Write enclosing function.
      s.writeln(
          '''  $funcPointerName: borrowed-c<$funcTypeName> = lib.lookup("$name")''');
      s.writeln(
          '''  $enclosingFuncName: $funcTypeName = $funcPointerName.cast()''');

      // if (exposeSymbolAddress) {
      //   // Add to SymbolAddress in writer.
      //   w.symbolAddressWriter.addSymbol(
      //     type:
      //         'Pointer<NativeFunction<$cType>>',
      //     name: name,
      //     ptrName: funcPointerName,
      //   );
      // }

      // Write function pointer.
//       s.write('''
// late final $funcPointerName = ${w.lookupFuncIdentifier}<
//     ${w.ffiLibraryPrefix}.NativeFunction<$cType>>('$originalName');
// late final $funcVarName = $funcPointerName.asFunction<$dartType>($isLeafString);

// ''');
    }

    return BindingString(type: BindingStringType.func, string: s.toString());
  }

  @override
  void addDependencies(Set<Binding> dependencies) {
    if (dependencies.contains(this)) return;

    dependencies.add(this);
    functionType.addDependencies(dependencies);
    if (exposeFunctionTypedefs) {
      _exposedFunctionTypealias!.addDependencies(dependencies);
    }
  }
}

/// Represents a Parameter, used in [Func] and [Typealias].
class Parameter {
  final String? originalName;
  String name;
  final Type type;

  Parameter({String? originalName, this.name = '', required Type type})
      : originalName = originalName ?? name,
        // A [NativeFunc] is wrapped with a pointer because this is a shorthand
        // used in C for Pointer to function.
        type = type.typealiasType is NativeFunc ? PointerType(type) : type;
}
