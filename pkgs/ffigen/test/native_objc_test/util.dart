// Copyright (c) 2022, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:ffigen/ffigen.dart';
import 'package:path/path.dart' as path;

import '../test_utils.dart';

void generateBindingsForCoverage(String testName) {
  // The ObjC test bindings are generated in setup.dart (see #362), which means
  // that the ObjC related bits of ffigen are missed by test coverage. So this
  // function just regenerates those bindings. It doesn't test anything except
  // that the generation succeeded, by asserting the file exists.
  final config = testConfig(
      File(path.join('test', 'native_objc_test', '${testName}_config.yaml'))
          .readAsStringSync());
  final library = parse(config);
  final file = File(
    path.join('test', 'debug_generated', '${testName}_test.dart'),
  );
  library.generateFile(file);
  assert(file.existsSync());
  file.delete();
}

@Native<Void Function(Pointer<Char>, Pointer<Void>)>(
    symbol: 'Dart_ExecuteInternalCommand')
external void _executeInternalCommand(Pointer<Char> cmd, Pointer<Void> arg);

void doGC() {
  final gcNow = "gc-now".toNativeUtf8();
  _executeInternalCommand(gcNow.cast(), nullptr);
  calloc.free(gcNow);
}
