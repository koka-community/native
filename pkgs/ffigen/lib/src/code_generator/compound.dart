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
  final bool isUnnamed;
  final bool isAnonymous;
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
    this.isUnnamed = false,
    this.isAnonymous = false,
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
    bool isUnnamed = false,
    bool isAnonymous = false,
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
          isUnnamed: isUnnamed,
          isAnonymous: isAnonymous,
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
          isUnnamed: isUnnamed,
          isAnonymous: isAnonymous,
        );
    }
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
      localUniqueNamer.markUsed(m.type.getKokaFFIType(w));
    }

    /// Write @Packed(X) annotation if struct is packed.
    if (isStruct && pack != null) {
      s.write('// Packed($pack)\n');
    }
    for (final m in members) {
      m.name = localUniqueNamer.makeUnique(m.name);
    }
    // Write class declaration.
    final kokaFfiName = getKokaFFIType(w);
    final kokaName = getKokaWrapperType(w);
    final kokaOwnedName = getKokaTypeOwned(w);
    final kokaBorrowedName = getKokaTypeBorrowed(w);
    final kokaOwnedArrayName = getKokaTypeOwnedArray(w);
    final kokaPointerName = '${kokaName}p';
    if (!sameWrapperAndFFIType) {
      if (members.length <= 3) {
        s.writeln('pub value struct $kokaName$typeParam');
      } else {
        s.writeln('pub struct $kokaName$typeParam');
      }
      const indent = '  ';
      for (final m in members) {
        if (m.dartDoc != null) {
          s.write('$indent// ');
          s.writeAll(m.dartDoc!.split('\n'), '\n$indent// ');
          s.writeln();
        }

        // if (!m.type.sameFfiDartAndCType) {
        //   s.writeln('$indent@${m.type.getCType(w)}()');
        // }
        if (m.type.baseType is Compound) {
          s.writeln('$indent${m.name}: ${m.type.baseType.getKokaFFIType(w)}');
        } else {
          s.writeln('$indent${m.name}: ${m.type.getKokaWrapperType(w)}');
        }
      }
      s.writeln();
    } else {
      s.writeln('pub struct $kokaName');
    }
    s.writeln('pub type $kokaFfiName');
    s.writeln(
        'pub alias $kokaPointerName = ${PointerType(this).getKokaWrapperType(w)}');
    s.writeln(
        'pub alias $kokaOwnedName = ${OwnedPointerType(this).getKokaWrapperType(w)}');
    s.writeln(
        'pub alias $kokaBorrowedName = ${BorrowedPointerType(this).getKokaWrapperType(w)}');
    s.writeln(
        'pub alias $kokaOwnedArrayName = ${OwnedPointerType(IncompleteArray(this)).getKokaWrapperType(w)}');
    s.writeln();

    if (!(isUnion || isIncomplete || isOpaque || isUnnamed)) {
      s.writeln('pub extern $kokaName/size-of(c: c-null<$kokaFfiName>): int32\n'
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
      if (w.generateCompoundMemberAccessors && !isUnnamed) {
        for (final m in members) {
          final mKokaName = m.name;
          final t = m.type;
          // Don't handle returning compound types by value
          if (t is Compound ||
              (t is Typealias && t.typealiasType is Compound)) {
            // TODO: Return compound types as borrowed references, and don't allow assignments to them.
            continue;
          }
          s.writeln(
              'pub inline extern $kokaName-ptrraw/$mKokaName(s: intptr_t): ${m.type.getKokaExternType(w)}\n'
              '  c inline "(${m.type.isPointerType ? 'intptr_t' : m.type.getRawCType(w)})((($cfulltype*)#1)->${m.originalName})"');
          s.writeln();
          final convertEffects =
              '<${m.type.convertExternToFFIEffects.join(',')}>';
          s.writeln(
              'pub inline fun ${kokaName}p/$mKokaName(s: $kokaPointerName): $convertEffects ${m.type.getKokaFFIType(w)}\n'
              '  ${m.type.convertExternTypeToFFI(w, 's.cextern/c-pointer/ptr.$kokaName-ptrraw/$mKokaName')}');
          s.writeln();

          s.writeln(
              'pub inline fun ${kokaName}c/$mKokaName(^s: $kokaOwnedName): $convertEffects ${m.type.getKokaFFIType(w)}\n'
              '  s.with-ptr(${kokaName}p/$mKokaName)');
          s.writeln();

          s.writeln(
              'pub inline fun ${kokaName}cb/$mKokaName(^s: $kokaBorrowedName): $convertEffects ${m.type.getKokaFFIType(w)}\n'
              '  s.with-ptr(${kokaName}p/$mKokaName)');
          s.writeln();

          s.writeln(
              'pub inline extern $kokaName-ptrraw/set-$mKokaName(s: intptr_t, $mKokaName: ${m.type.getKokaExternType(w)}): ()\n'
              '  c inline "(($cfulltype*)#1)->${m.originalName} = (${m.type.getRawCType(w)})#2"');
          s.writeln();

          s.writeln(
              'pub inline fun ${kokaName}p/set-$mKokaName(s: $kokaPointerName, $mKokaName: ${m.type.getKokaFFIType(w)}): ()\n'
              '  s.cextern/c-pointer/ptr.$kokaName-ptrraw/set-$mKokaName(${m.type.convertFFITypeToExtern(w, mKokaName)})');
          s.writeln();

          s.writeln(
              'pub inline fun ${kokaName}c/set-$mKokaName(^s: $kokaOwnedName, $mKokaName: ${m.type.getKokaFFIType(w)}): ()\n'
              '  s.with-ptr(fn(kk-internal-ptr) kk-internal-ptr.${kokaName}p/set-$mKokaName($mKokaName))');
          s.writeln();

          s.writeln(
              'pub inline fun ${kokaName}cb/set-$mKokaName(^s: $kokaBorrowedName, $mKokaName: ${m.type.getKokaFFIType(w)}): ()\n'
              '  s.with-ptr(fn(kk-internal-ptr) kk-internal-ptr.${kokaName}p/set-$mKokaName($mKokaName))');
          s.writeln();

          if (!m.type.sameWrapperAndFFIType) {
            s.writeln(
                'pub inline fun ${kokaName}c-wrapper/$mKokaName(^s: $kokaOwnedName): ${m.type.getKokaWrapperType(w)}');
            final reso = m.type.convertFFITypeToWrapper(
                w, 's.with-ptr(${kokaName}p/$mKokaName)',
                objCRetain: false,
                additionalStatements: s,
                namer: UniqueNamer({'s'}));
            s.writeln('  $reso\n');

            s.writeln(
                'pub inline fun ${kokaName}cb-wrapper/$mKokaName(^s: $kokaBorrowedName): ${m.type.getKokaWrapperType(w)}');
            final resb = m.type.convertFFITypeToWrapper(
                w, 's.with-ptr(${kokaName}p/$mKokaName)',
                objCRetain: false,
                additionalStatements: s,
                namer: UniqueNamer({'s'}));
            s.writeln('  $resb\n');

            s.write(
                'pub inline fun ${kokaName}c-wrapper/set-$mKokaName(^s: $kokaOwnedName, $mKokaName: ${m.type.getKokaWrapperType(w)}): ()\n  ');
            final argo = m.type.convertWrapperToFFIType(w, mKokaName,
                objCRetain: false,
                additionalStatements: s,
                namer: UniqueNamer({'s', mKokaName}));
            s.writeln(
                's.with-ptr(fn(kk-internal-ptr) kk-internal-ptr.${kokaName}p/set-$mKokaName($argo))\n');

            s.write(
                'pub inline fun ${kokaName}cb-wrapper/set-$mKokaName(^s: $kokaBorrowedName, $mKokaName: ${m.type.getKokaWrapperType(w)}): ()\n  ');
            final argb = m.type.convertWrapperToFFIType(w, mKokaName,
                objCRetain: false,
                additionalStatements: s,
                namer: UniqueNamer({'s', mKokaName}));
            s.writeln(
                's.with-ptr(fn(kk-internal-ptr) kk-internal-ptr.${kokaName}p/set-$mKokaName($argb))\n');
          }
        }
      }
      // if (!sameWrapperAndFFIType) {
      //   s.writeln(
      //       'pub fun ${kokaName}p/to-koka(s: $kokaPointerName): $kokaName');
      //   final args = members.map((m) => m.type.sameWrapperAndFFIType
      //       ? 's.$kokaPointerName/${m.name}'
      //       : m.type.baseType is Compound
      //           ? m.type.convertFFITypeToWrapper(
      //                   w, 's.$kokaPointerName/${m.name}',
      //                   objCRetain: false,
      //                   additionalStatements: s,
      //                   namer: UniqueNamer({'s'})) +
      //               '.to-koka'
      //           : m.type.convertFFITypeToWrapper(
      //               w, 's.$kokaPointerName/${m.name}',
      //               objCRetain: false,
      //               additionalStatements: s,
      //               namer: UniqueNamer({'s'})));
      //   s.writeln('  ${kokaName.capitalize}(${args.join(', ')})\n');
      // }
    } else if (isOpaque) {
      // s.writeln(
      //     'pub fun $kokaName/to-koka(s: $kokaPointerName): $kokaName\n  ${kokaName.capitalize}()\n');
    }
    return BindingString(
        type: isStruct ? BindingStringType.struct : BindingStringType.union,
        string: s.toString());
  }

  late final cfulltype = isAnonymous
      ? originalName
      : isStruct
          ? 'struct $originalName'
          : 'union $originalName';

  @override
  void addDependencies(Set<Binding> dependencies) {
    if (dependencies.contains(this)) return;

    dependencies.add(this);
    for (final m in members) {
      m.type.addDependencies(dependencies);
    }
  }

  @override
  String getRawCType(Writer w) => cfulltype;

  @override
  bool get isIncompleteCompound => isIncomplete;

  @override
  String getKokaExternType(Writer w) => name;

  @override
  String getKokaFFIType(Writer w) => "$name-c";

  @override
  String getKokaWrapperType(Writer w) => name;
  late final bool hasArrayMember = members.any((m) => m.type is ConstantArray);
  late final typeParam = (hasArrayMember ? '<s::S>' : '');
  String getKokaTypeOwned(Writer w) => getKokaWrapperType(w) + 'c' + typeParam;
  String getKokaTypeBorrowed(Writer w) => getKokaWrapperType(w) + 'cb<s::S>';
  String getKokaTypeOwnedArray(Writer w) =>
      getKokaWrapperType(w) + 'ca' + typeParam;

  @override
  String convertFFITypeToWrapper(
    Writer w,
    String value, {
    required bool objCRetain,
    String? objCEnclosingClass,
    required StringBuffer additionalStatements,
    required UniqueNamer namer,
  }) =>
      sameWrapperAndFFIType ? value : '$value';

  @override
  String convertWrapperToFFIType(Writer w, String value,
      {required bool objCRetain,
      required StringBuffer additionalStatements,
      required UniqueNamer namer}) {
    return 'throw("Not implemented")';
  }

  @override
  bool get sameExternAndFFIType => false;

  @override
  bool get sameWrapperAndFFIType =>
      isUnion || isIncomplete || isOpaque || hasArrayMember;

  @override
  bool get sameWrapperAndExternType => false;
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
