// Copyright (c) 2021, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:ffigen/src/code_generator.dart';

import 'binding_string.dart';
import 'utils.dart';
import 'writer.dart';

enum CompoundType { struct, union }

/// A binding for Compound type - Struct/Union.
abstract class Compound extends BindingType {
  /// Marker for if a struct definition is complete.
  ///
  /// A function can be safely pass this struct by value if it's complete.
  bool isIncomplete;

  List<Member> members;

  bool get isOpaque => members.isEmpty;

  /// Value for `@Packed(X)` annotation. Can be null (no packing), 1, 2, 4, 8,
  /// or 16.
  ///
  /// Only supported for [CompoundType.struct].
  int? pack;

  /// Marker for checking if the dependencies are parsed.
  bool parsedDependencies = false;

  CompoundType compoundType;
  bool get isStruct => compoundType == CompoundType.struct;
  bool get isUnion => compoundType == CompoundType.union;

  Compound({
    super.usr,
    super.originalName,
    required super.name,
    required this.compoundType,
    this.isIncomplete = false,
    this.pack,
    super.dartDoc,
    List<Member>? members,
    super.isInternal,
  }) : members = members ?? [];

  factory Compound.fromType({
    required CompoundType type,
    String? usr,
    String? originalName,
    required String name,
    bool isIncomplete = false,
    int? pack,
    String? dartDoc,
    List<Member>? members,
  }) {
    switch (type) {
      case CompoundType.struct:
        return Struct(
          usr: usr,
          originalName: originalName,
          name: name,
          isIncomplete: isIncomplete,
          pack: pack,
          dartDoc: dartDoc,
          members: members,
        );
      case CompoundType.union:
        return Union(
          usr: usr,
          originalName: originalName,
          name: name,
          isIncomplete: isIncomplete,
          pack: pack,
          dartDoc: dartDoc,
          members: members,
        );
    }
  }

  String _getInlineArrayTypeString(Type type, Writer w) {
    if (type is ConstantArray) {
      return 'c-array<'
          '${_getInlineArrayTypeString(type.child, w)}>';
    }
    return type.getCType(w);
  }

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

    /// Marking type names because koka doesn't allow class member to have the
    /// same name as a type name used internally.
    for (final m in members) {
      localUniqueNamer.markUsed(m.type.getFfiDartType(w));
    }

    /// Write @Packed(X) annotation if struct is packed.
    if (isStruct && pack != null) {
      s.write('// Packed($pack)\n');
    }
    // Write class declaration.
    final kokaFfiName = getFfiDartType(w);
    final kokaName = getDartType(w);
    final kokaOwnedName = getDartTypeOwned(w);
    final kokaBorrowedName = getDartTypeBorrowed(w);
    final kokaOwnedArrayName = getDartTypeOwnedArray(w);
    if (!sameDartAndFfiDartType) {
      if (members.length <= 3) {
        s.writeln('pub value struct $kokaName$typeParam');
      } else {
        s.writeln('pub struct $kokaName$typeParam');
      }
      const indent = '  ';
      for (final m in members) {
        m.name = localUniqueNamer
            .makeUnique(m.name.toLowerCase().replaceAll('_', '-'));

        if (m.dartDoc != null) {
          s.write('$indent// ');
          s.writeAll(m.dartDoc!.split('\n'), '\n$indent// ');
          s.writeln();
        }
        if (m.type case final ConstantArray arrayType) {
          s.writeln(makeArrayAnnotation(w, arrayType));
          s.writeln(
              '$indent${m.name}: borrowed-c<s,${_getInlineArrayTypeString(m.type, w)}>');
        } else {
          // if (!m.type.sameFfiDartAndCType) {
          //   s.writeln('$indent@${m.type.getCType(w)}()');
          // }
          if (m.type.baseType is Compound) {
            s.writeln('$indent${m.name}: ${m.type.baseType.getDartType(w)}');
          } else {
            s.writeln('$indent${m.name}: ${m.type.getDartType(w)}');
          }
        }
      }
      s.writeln();
    } else if (isOpaque) {
      s.writeln('pub struct $kokaName');
    }
    s.writeln('pub type $kokaFfiName');
    s.writeln('pub alias $kokaOwnedName = ${PointerType(this).getDartType(w)}');
    s.writeln(
        'pub alias $kokaBorrowedName = ${BorrowedPointerType(this).getDartType(w)}');
    s.writeln(
        'pub alias $kokaOwnedArrayName = ${IncompleteArray(this).getDartType(w)}');
    s.writeln();

    if (!isOpaque) {
      s.writeln('extern $kokaName/size-of(c: c-null<$kokaFfiName>): int32\n'
          '  c inline "sizeof($cfulltype)"\n');

      s.writeln('pub fun ${kokaName}c(): $kokaOwnedName\n'
          '  malloc(?size-of=$kokaName/size-of)');
      s.writeln();
      s.writeln('pub fun ${kokaName}c-calloc(): $kokaOwnedName\n'
          '  malloc-c(?size-of=$kokaName/size-of)');
      s.writeln();

      s.writeln('pub fun ${kokaName}c-array(n: int): $kokaOwnedArrayName\n'
          '  malloc(n.int32, ?size-of=$kokaName/size-of)');
      s.writeln();

      s.writeln(
          'pub fun ${kokaName}c-array-calloc(n: int): $kokaOwnedArrayName\n'
          '  malloc-c(n.int32, ?size-of=$kokaName/size-of)');
      s.writeln();

      for (final m in members) {
        final mKokaName = m.name;
        if (m.type is ConstantArray) {
          continue;
        }
        s.writeln(
            'inline extern $kokaName-ptr/$mKokaName(s: intptr_t): ${m.type.getFfiDartType(w)}\n'
            '  c inline "(${m.type.isPointerType ? 'intptr_t' : m.type.getCType(w)})((($cfulltype*)#1)->${m.originalName})"');
        s.writeln();

        s.writeln(
            'pub inline fun ${kokaName}c/$mKokaName(^s: $kokaOwnedName): ${m.type.getFfiDartType(w)}\n'
            '  s.with-ptr($kokaName-ptr/$mKokaName)');
        s.writeln();

        s.writeln(
            'pub inline fun ${kokaName}cb/$mKokaName(^s: $kokaBorrowedName): ${m.type.getFfiDartType(w)}\n'
            '  s.with-ptr($kokaName-ptr/$mKokaName)');
        s.writeln();

        s.writeln(
            'inline extern $kokaName-ptr/set-$mKokaName(s: intptr_t, $mKokaName: ${m.type.getFfiDartType(w)}): ()\n'
            '  c inline "(($cfulltype*)#1)->${m.originalName} = (${m.type.baseType is Compound && m.type.isPointerType ? (m.type.baseType as Compound).cfulltype + "*" : m.type.getCType(w)})#2"');
        s.writeln();

        s.writeln(
            'pub inline fun ${kokaName}c/set-$mKokaName(^s: $kokaOwnedName, $mKokaName: ${m.type.getFfiDartType(w)}): ()\n'
            '  s.with-ptr(fn(kk-internal-ptr) kk-internal-ptr.$kokaName-ptr/set-$mKokaName($mKokaName))');
        s.writeln();

        s.writeln(
            'pub inline fun ${kokaName}cb/set-$mKokaName(^s: $kokaBorrowedName, $mKokaName: ${m.type.getFfiDartType(w)}): ()\n'
            '  s.with-ptr(fn(kk-internal-ptr) kk-internal-ptr.$kokaName-ptr/set-$mKokaName($mKokaName))');
        s.writeln();

        if (!m.type.sameDartAndFfiDartType) {
          s.writeln(
              'pub inline fun ${kokaName}c-wrapper/$mKokaName(^s: $kokaOwnedName): ${m.type.getDartType(w)}');
          final reso = m.type.convertFfiDartTypeToDartType(
              w, 's.with-ptr($kokaName-ptr/$mKokaName)',
              objCRetain: false,
              additionalStatements: s,
              namer: UniqueNamer({'s'}));
          s.writeln('  $reso\n');

          s.writeln(
              'pub inline fun ${kokaName}cb-wrapper/$mKokaName(^s: $kokaBorrowedName): ${m.type.getDartType(w)}');
          final resb = m.type.convertFfiDartTypeToDartType(
              w, 's.with-ptr($kokaName-ptr/$mKokaName)',
              objCRetain: false,
              additionalStatements: s,
              namer: UniqueNamer({'s'}));
          s.writeln('  $resb\n');

          s.write(
              'pub inline fun ${kokaName}c-wrapper/set-$mKokaName(^s: $kokaOwnedName, $mKokaName: ${m.type.getDartType(w)}): ()\n  ');
          final argo = m.type.convertDartTypeToFfiDartType(w, mKokaName,
              objCRetain: false,
              additionalStatements: s,
              namer: UniqueNamer({'s', mKokaName}));
          s.writeln(
              's.with-ptr(fn(kk-internal-ptr) kk-internal-ptr.$kokaName-ptr/set-$mKokaName($argo))\n');

          s.write(
              'pub inline fun ${kokaName}cb-wrapper/set-$mKokaName(^s: $kokaBorrowedName, $mKokaName: ${m.type.getDartType(w)}): ()\n  ');
          final argb = m.type.convertDartTypeToFfiDartType(w, mKokaName,
              objCRetain: false,
              additionalStatements: s,
              namer: UniqueNamer({'s', mKokaName}));
          s.writeln(
              's.with-ptr(fn(kk-internal-ptr) kk-internal-ptr.$kokaName-ptr/set-$mKokaName($argb))\n');
        }
      }
      if (!sameDartAndFfiDartType) {
        s.writeln('pub fun $kokaName/to-koka(s: $kokaOwnedName): $kokaName');
        final args = members.map((m) => m.type.sameDartAndFfiDartType
            ? 's.${kokaName}c/${m.name}'
            : m.type.baseType is Compound
                ? m.type.convertFfiDartTypeToDartType(
                        w, 's.${kokaName}c/${m.name}',
                        objCRetain: false,
                        additionalStatements: s,
                        namer: UniqueNamer({'s'})) +
                    '.to-koka'
                : m.type.convertFfiDartTypeToDartType(
                    w, 's.${kokaName}c/${m.name}',
                    objCRetain: false,
                    additionalStatements: s,
                    namer: UniqueNamer({'s'})));
        s.writeln('  ${kokaName.capitalize}(${args.join(', ')})\n');
      }
    } else if (isOpaque) {
      s.writeln(
          'pub fun $kokaName/to-koka(s: $kokaOwnedName): $kokaName\n  ${kokaName.capitalize}()\n');
    }
    return BindingString(
        type: isStruct ? BindingStringType.struct : BindingStringType.union,
        string: s.toString());
  }

  late final cfulltype =
      isStruct ? 'struct $originalName' : 'union $originalName';

  @override
  void addDependencies(Set<Binding> dependencies) {
    if (dependencies.contains(this)) return;

    dependencies.add(this);
    for (final m in members) {
      m.type.addDependencies(dependencies);
    }
  }

  @override
  bool get isIncompleteCompound => isIncomplete;

  @override
  String getCType(Writer w) => name;

  @override
  String getFfiDartType(Writer w) =>
      "${name.toLowerCase().replaceAll('_', '-')}-c";

  @override
  String getDartType(Writer w) => name.toLowerCase().replaceAll('_', '-');
  late final bool hasArrayMember = members.any((m) => m.type is ConstantArray);
  late final typeParam = (hasArrayMember ? '<s::S>' : '');
  String getDartTypeOwned(Writer w) => getDartType(w) + 'c' + typeParam;
  String getDartTypeBorrowed(Writer w) => getDartType(w) + 'cb<s::S>';
  String getDartTypeOwnedArray(Writer w) => getDartType(w) + 'ca' + typeParam;
  @override
  String convertFfiDartTypeToDartType(
    Writer w,
    String value, {
    required bool objCRetain,
    String? objCEnclosingClass,
    required StringBuffer additionalStatements,
    required UniqueNamer namer,
  }) =>
      sameDartAndFfiDartType ? value : '$value.to-koka';

  @override
  String convertDartTypeToFfiDartType(Writer w, String value,
      {required bool objCRetain,
      required StringBuffer additionalStatements,
      required UniqueNamer namer}) {
    return '($cfulltype)($value)';
  }

  @override
  bool get sameFfiDartAndCType => false;

  @override
  bool get sameDartAndFfiDartType =>
      isUnion || isIncomplete || isOpaque || hasArrayMember;

  @override
  bool get sameDartAndCType => false;
}

class Member {
  final String? dartDoc;
  final String originalName;
  String name;
  final Type type;

  Member({
    String? originalName,
    required this.name,
    required this.type,
    this.dartDoc,
  }) : originalName = originalName ?? name;
}
