// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'binding.dart';
import 'binding_string.dart';
import 'native_type.dart';
import 'type.dart';
import 'utils.dart';
import 'writer.dart';

/// A binding for enums in C.
///
/// For a C enum -
/// ```c
/// enum Fruits {apple, banana = 10};
/// ```
/// The generated dart code is
///
/// ```dart
/// class Fruits {
///   static const apple = 0;
///   static const banana = 10;
/// }
/// ```
class EnumClass extends BindingType {
  static final nativeType = NativeType(SupportedNativeType.Int32);

  final List<EnumConstant> enumConstants;

  EnumClass({
    super.usr,
    super.originalName,
    required super.name,
    super.dartDoc,
    List<EnumConstant>? enumConstants,
  }) : enumConstants = enumConstants ?? [];

  @override
  BindingString toBindingString(Writer w) {
    final s = StringBuffer();
    final enclosingClassName = name;

    if (dartDoc != null) {
      s.write(makeDoc(dartDoc!));
    }

    /// Adding [enclosingClassName] because dart doesn't allow class member
    /// to have the same name as the class.
    final localUniqueNamer = UniqueNamer({enclosingClassName});

    // Print enclosing class.
    final typeName = enclosingClassName;
    s.writeln('type ${typeName}');
    const indent = '  ';
    final names = {
      for (final ec in enumConstants)
        ec: localUniqueNamer
            .makeUnique(ec.name)
            .replaceAll('-', '_')
            .toUpperCase()
    };
    for (final ec in enumConstants) {
      final enumValueName = names[ec];
      if (ec.dartDoc != null) {
        s.write('$indent// ');
        s.writeAll(ec.dartDoc!.split('\n'), '\n$indent// ');
        s.write('\n');
      }
      s.writeln('${indent}$enumValueName');
    }
    s.writeln();
    s.writeln('pub fun ${typeName}/int(i: ${typeName}): int');
    s.writeln('  match i');
    for (final ec in enumConstants) {
      final enumValueName = names[ec];
      s.writeln('    ${enumValueName} -> ${ec.value}');
    }

    s.writeln();
    s.writeln('pub fun int/${typeName}(i: int): exn ${typeName}');
    s.writeln('  match i');
    for (final ec in enumConstants) {
      final enumValueName = names[ec];
      s.writeln('    ${ec.value} -> ${enumValueName}');
    }
    s.writeln();
    return BindingString(
        type: BindingStringType.enumClass, string: s.toString());
  }

  @override
  void addDependencies(Set<Binding> dependencies) {
    if (dependencies.contains(this)) return;

    dependencies.add(this);
  }

  @override
  String getKokaExternType(Writer w) => nativeType.getKokaExternType(w);

  @override
  String getKokaFFIType(Writer w) => nativeType.getKokaFFIType(w);

  @override
  bool get sameExternAndFFIType => nativeType.sameExternAndFFIType;

  @override
  bool get sameWrapperAndExternType => nativeType.sameWrapperAndExternType;

  @override
  String? getDefaultValue(Writer w) => '0';
}

/// Represents a single value in an enum.
class EnumConstant {
  final String? originalName;
  final String? dartDoc;
  final String name;
  final int value;
  const EnumConstant({
    String? originalName,
    required this.name,
    required this.value,
    this.dartDoc,
  }) : originalName = originalName ?? name;
}
