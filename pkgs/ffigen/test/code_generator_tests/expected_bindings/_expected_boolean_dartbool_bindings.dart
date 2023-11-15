// AUTO GENERATED FILE, DO NOT EDIT.
//
// Generated by `package:ffigen`.
// ignore_for_file: type=lint
import 'dart:ffi' as ffi;

class Bindings {
  /// Holds the symbol lookup function.
  final ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
      _lookup;

  /// The symbols are looked up in [dynamicLibrary].
  Bindings(ffi.DynamicLibrary dynamicLibrary) : _lookup = dynamicLibrary.lookup;

  /// The symbols are looked up with [lookup].
  Bindings.fromLookup(
      ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
          lookup)
      : _lookup = lookup;

  bool test1(
    bool a,
    ffi.Pointer<ffi.Bool> b,
  ) {
    return _test1(
      a,
      b,
    );
  }

  late final _test1Ptr = _lookup<
      ffi.NativeFunction<
          ffi.Bool Function(ffi.Bool, ffi.Pointer<ffi.Bool>)>>('test1');
  late final _test1 =
      _test1Ptr.asFunction<bool Function(bool, ffi.Pointer<ffi.Bool>)>();
}

final class Test2 extends ffi.Struct {
  @ffi.Bool()
  external bool a;
}