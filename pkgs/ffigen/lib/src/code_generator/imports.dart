// Copyright (c) 2022, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'native_type.dart';
import 'type.dart';
import 'writer.dart';

/// A library import which will be written as an import in the generated file.
class LibraryImport {
  final String name;
  final String _importPath;
  final String? _importPathWhenImportedByPackageObjC;

  String prefix;

  LibraryImport(this.name, this._importPath,
      {String? importPathWhenImportedByPackageObjC})
      : _importPathWhenImportedByPackageObjC =
            importPathWhenImportedByPackageObjC,
        prefix = name;

  @override
  bool operator ==(other) {
    return other is LibraryImport && name == other.name;
  }

  @override
  int get hashCode => name.hashCode;

  // The import path, which may be different if this library is being imported
  // into package:objective_c's generated code.
  String importPath(bool generateForPackageObjectiveC) {
    if (!generateForPackageObjectiveC) return _importPath;
    return _importPathWhenImportedByPackageObjC ?? _importPath;
  }
}

/// An imported type which will be used in the generated code.
class ImportedType extends Type {
  final LibraryImport libraryImport;
  final String cType;
  final String dartType;
  final String? defaultValue;

  ImportedType(this.libraryImport, this.cType, this.dartType,
      [this.defaultValue]);

  @override
  String getCType(Writer w) {
    w.markImportUsed(libraryImport);
    return '${libraryImport.prefix}.$cType';
  }

  @override
  String getFfiDartType(Writer w) => cType == dartType ? getCType(w) : dartType;

  @override
  bool get sameFfiDartAndCType => cType == dartType;

  @override
  String toString() => '${libraryImport.name}.$cType';

  @override
  String? getDefaultValue(Writer w) => defaultValue;
}

/// An unchecked type similar to [ImportedType] which exists in the generated
/// binding itself.
class SelfImportedType extends Type {
  final String cType;
  final String dartType;
  final String? defaultValue;

  SelfImportedType(this.cType, this.dartType, [this.defaultValue]);

  @override
  String getCType(Writer w) => cType;

  @override
  String getFfiDartType(Writer w) => dartType;

  @override
  bool get sameFfiDartAndCType => cType == dartType;

  @override
  String toString() => cType;
}

final ffiImport = LibraryImport('ffi', 'std/cextern');
final ffiPkgImport = LibraryImport('pkg_ffi', 'package:ffi/ffi.dart');
final objcPkgImport = LibraryImport(
    'objc', 'package:objective_c/objective_c.dart',
    importPathWhenImportedByPackageObjC: '../objective_c.dart');
final self = LibraryImport('self', '');

final voidType = NativeType.other('()', '()', '()');

final unsignedCharType = NativeType.other('int8', 'int8', '0');
final signedCharType = NativeType.other('int8', 'int8', '0');
final charType = NativeType.other('int8', 'int8', '0');
final unsignedShortType = NativeType.other('int16', 'int16', '0');
final shortType = NativeType.other('int16', 'int16', '0');
final unsignedIntType = NativeType.other('int32', 'int32', '0');
final intType = NativeType.other('int32', 'int32', '0');
final unsignedLongType = NativeType.other('int64', 'int64', '0');
final longType = NativeType.other('int64', 'int64', '0');
final unsignedLongLongType = NativeType.other('int64', 'int64', '0');
final longLongType = NativeType.other('int64', 'int64', '0');

final floatType = NativeType.other('int64', 'int64', '0.0');
final doubleType = NativeType.other('int64', 'int64', '0.0');

final sizeType = NativeType.other('ssize_t', 'ssize_t', '0');
final wCharType = NativeType.other('wchar', 'int', '0');

final objCObjectType = NativeType.other('ObjCObject', 'ObjCObject', null);
final objCSelType = NativeType.other('ObjCSelector', 'ObjCSelector', null);
final objCBlockType = NativeType.other('ObjCBlock', 'ObjCBlock', null);
