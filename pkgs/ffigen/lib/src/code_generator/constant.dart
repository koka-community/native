// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'binding.dart';
import 'binding_string.dart';
import 'utils.dart';
import 'writer.dart';

/// A simple Constant.
///
/// Expands to -
/// ```dart
/// const <type> <name> = <rawValue>;
/// ```
///
/// Example -
/// ```dart
/// const int name = 10;
/// ```
class Constant extends NoLookUpBinding {
  /// The rawType is pasted as it is. E.g 'int', 'String', 'double'
  final String rawType;

  /// The rawValue is pasted as it is.
  ///
  /// Put quotes if type is a string.
  final String rawValue;

  Constant({
    super.usr,
    super.originalName,
    required super.name,
    super.dartDoc,
    required this.rawType,
    required this.rawValue,
  });

  @override
  BindingString toBindingString(Writer w) {
    final s = StringBuffer();
    final constantName = name;

    if (dartDoc != null) {
      s.writeln(makeDoc(dartDoc!));
    }

    s.writeln('pub val k${constantName.toLowerCase()}: $rawType = $rawValue\n');

    return BindingString(
        type: BindingStringType.constant, string: s.toString());
  }

  @override
  void addDependencies(Set<Binding> dependencies) {
    if (dependencies.contains(this)) return;

    dependencies.add(this);
  }
}
