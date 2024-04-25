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
    final kokaClassName = isStruct ? 'struct' : 'type';
    // Write class declaration.
    final kokaFfiName = getFfiDartType(w);
    final kokaName = getDartType(w);
    if (!isOpaque) {
      s.writeln('pub $kokaClassName ${kokaName}');
      const indent = '  ';
      for (final m in members) {
        m.name = localUniqueNamer.makeUnique(m.name);
        if (m.dartDoc != null) {
          s.write('$indent// ');
          s.writeAll(m.dartDoc!.split('\n'), '\n$indent// ');
          s.writeln();
        }
        if (m.type case final ConstantArray arrayType) {
          s.writeln(makeArrayAnnotation(w, arrayType));
          s.writeln(
              '$indent${m.name}: ${_getInlineArrayTypeString(m.type, w)}');
        } else {
          // if (!m.type.sameFfiDartAndCType) {
          //   s.writeln('$indent@${m.type.getCType(w)}()');
          // }
          s.writeln('$indent${m.name}: ${m.type.getFfiDartType(w)}');
        }
      }
      s.writeln();
    }
    s.writeln('pub type $kokaFfiName');
    s.writeln('alias ${name.toLowerCase()}c = owned-c<$kokaFfiName>');
    s.writeln(
        'alias ${name.toLowerCase()}cb<s> = borrowed-c<s,${kokaFfiName}>');
    s.writeln(
        'alias ${name.toLowerCase()}ca = owned-c<c-array<${kokaFfiName}>>\n');
    if (!isOpaque) {
      s.writeln('extern ${kokaName}/size-of(c: c-null<$kokaFfiName>): int32\n'
          '  c inline "sizeof($originalName)"');

      s.writeln();

      s.writeln('pub fun ${kokaName}c(): ${kokaName}c\n'
          '  malloc()');
      s.writeln();
      s.writeln('pub fun ${kokaName}c-calloc(): ${kokaName}c\n'
          '  malloc-c()');
      s.writeln();

      s.writeln('pub fun ${kokaName}c-array(n: int): ${kokaName}ca\n'
          '  malloc(n.int32)');
      s.writeln();

      s.writeln('pub fun ${kokaName}c-array-calloc(n: int): ${kokaName}ca\n'
          '  malloc-c(n.int32)');
      s.writeln();

      for (final m in members) {
        s.writeln(
            'inline extern ${kokaName}-ptr/${m.name}(s: intptr_t): ${m.type.getFfiDartType(w)}\n'
            '  c inline "(($originalName*)#1)->${m.originalName}"');
        s.writeln();

        s.writeln(
            'pub inline fun ${kokaName}c/${m.name}(^s: ${kokaName}c): ${m.type.getFfiDartType(w)}\n'
            '  s.with-ptr(${kokaName}-ptr/${m.name})');
        s.writeln();

        s.writeln(
            'pub inline fun ${kokaName}cb/${m.name}(^s: ${kokaName}cb<s>): ${m.type.getFfiDartType(w)}\n'
            '  s.with-ptr(${kokaName}-ptr/${m.name})');
        s.writeln();

        s.writeln(
            'inline extern ${kokaName}-ptr/set-${m.name}(s: intptr_t, ${m.name}: ${m.type.getFfiDartType(w)}): ()\n'
            '  c inline "(($originalName*)#1)->${m.originalName} = #2"');
        s.writeln();

        s.writeln(
            'pub inline fun ${kokaName}c/set-${m.name}(^s: ${kokaName}c, ${m.name}: ${m.type.getFfiDartType(w)}): ()\n'
            '  s.with-ptr(fn(p) p.${kokaName}-ptr/set-${m.name}(${m.name}))');
        s.writeln();

        s.writeln(
            'pub inline fun ${kokaName}cb/set-${m.name}(^s: ${kokaName}cb<s>, ${m.name}: ${m.type.getFfiDartType(w)}): ()\n'
            '  s.with-ptr(fn(p) p.${kokaName}-ptr/set-${m.name}(${m.name}))');
        s.writeln();
      }

      s.writeln('pub fun ${kokaName}/to-koka(s: ${kokaName}c): $kokaName\n'
          '  ${kokaName.capitalize}(${members.map((m) => 's.${m.name}').join(', ')})');
    }
    return BindingString(
        type: isStruct ? BindingStringType.struct : BindingStringType.union,
        string: s.toString());
  }

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
  String getFfiDartType(Writer w) => name.toLowerCase() + "-c";

  @override
  String getDartType(Writer w) =>
      isOpaque ? getFfiDartType(w) : name.toLowerCase();

  @override
  bool get sameFfiDartAndCType => false;

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
