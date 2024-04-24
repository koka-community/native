// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../config_provider/config_types.dart';
import 'binding.dart';
import 'binding_string.dart';
import 'compound.dart';
import 'pointer.dart';
import 'type.dart';
import 'utils.dart';
import 'writer.dart';

/// A binding to a global variable
///
/// For a C global variable -
/// ```c
/// int a;
/// ```
/// The generated dart code is -
/// ```dart
/// final int a = _dylib.lookup<ffi.Int32>('a').value;
/// ```
class Global extends LookUpBinding {
  final Type type;
  final bool exposeSymbolAddress;
  final FfiNativeConfig nativeConfig;
  final bool constant;

  Global({
    super.usr,
    super.originalName,
    required super.name,
    required this.type,
    super.dartDoc,
    this.exposeSymbolAddress = false,
    this.constant = false,
    this.nativeConfig = const FfiNativeConfig(enabled: false),
  });

  @override
  BindingString toBindingString(Writer w) {
    final s = StringBuffer();
    final globalVarName = name;
    if (dartDoc != null) {
      s.write(makeDoc(dartDoc!));
    }
    final kokaType = type.getDartType(w);
    final kokaFfiType = type.getFfiDartType(w);
    final cType = type.getCType(w);

    if (nativeConfig.enabled) {
      // if (type case final ConstantArray arr) {
      //   s.writeln(makeArrayAnnotation(w, arr));
      // }
      // print("$type ${type.runtimeType}");
      s.writeln('pub extern external/$globalVarName(): $kokaFfiType\n'
          '  c inline "$name"\n');
      if (constant) {
        s.writeln(
            'pub val wrapper/$globalVarName: $kokaType = ${type.convertFfiDartTypeToDartType(w, 'external/$globalVarName()', objCRetain: false)}\n');
      } else {
        s.writeln('pub fun wrapper/$globalVarName(): $kokaType\n'
            '  ${type.convertFfiDartTypeToDartType(w, 'external/$globalVarName()', objCRetain: true)}\n');
      }

      if (exposeSymbolAddress) {
        w.symbolAddressWriter.addNativeSymbol(
            type: '${w.ffiLibraryPrefix}.c-owned<$cType>', name: name);
      }
    } else {
      final pointerName =
          w.wrapperLevelUniqueNamer.makeUnique('_$globalVarName');

      s.write(
          "val $pointerName: ${w.ffiLibraryPrefix}.c-owned<$cType> = ${w.lookupFuncIdentifier}<$cType>('$originalName')\n\n");
      final baseTypealiasType = type.typealiasType;
      if (baseTypealiasType is Compound) {
        if (baseTypealiasType.isOpaque) {
          s.write(
              'val $globalVarName: ${w.ffiLibraryPrefix}.c-owned<$cType> = $pointerName\n\n');
        } else {
          s.write('val $globalVarName: $kokaType = $pointerName.ref\n\n');
        }
      } else {
        s.write('val $globalVarName: $kokaType = $pointerName.value\n\n');
        if (!constant) {
          s.write('fun set-$globalVarName(value: $kokaType)\n'
              '  $pointerName.value = value\n\n');
        }
      }

      if (exposeSymbolAddress) {
        // Add to SymbolAddress in writer.
        w.symbolAddressWriter.addSymbol(
          type: '${w.ffiLibraryPrefix}.c-owned<$cType>',
          name: name,
          ptrName: pointerName,
        );
      }
    }

    return BindingString(type: BindingStringType.global, string: s.toString());
  }

  @override
  void addDependencies(Set<Binding> dependencies) {
    if (dependencies.contains(this)) return;

    dependencies.add(this);
    type.addDependencies(dependencies);
  }
}
