// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'c_bindings_generated.dart' as c;

Pointer<c.ObjCSelector> registerName(String name) {
  final cstr = name.toNativeUtf8();
  final sel = c.registerName(cstr.cast());
  calloc.free(cstr);
  return sel;
}

Pointer<c.ObjCObject> getClass(String name) {
  final cstr = name.toNativeUtf8();
  final clazz = c.getClass(cstr.cast());
  calloc.free(cstr);
  if (clazz == nullptr) {
    throw Exception('Failed to load Objective-C class: $name');
  }
  return clazz;
}

final msgSendPointer =
    Native.addressOf<NativeFunction<Void Function()>>(c.msgSend);
final msgSendFpretPointer =
    Native.addressOf<NativeFunction<Void Function()>>(c.msgSendFpret);
final msgSendStretPointer =
    Native.addressOf<NativeFunction<Void Function()>>(c.msgSendStret);

final useMsgSendVariants =
    Abi.current() == Abi.iosX64 || Abi.current() == Abi.macosX64;

class _ObjCFinalizable<T extends NativeType> implements Finalizable {
  final Pointer<T> _ptr;
  bool _pendingRelease;

  _ObjCFinalizable(this._ptr, {required bool retain, required bool release})
      : _pendingRelease = release {
    if (retain) {
      _retain(_ptr.cast());
    }
    if (release) {
      _finalizer.attach(this, _ptr.cast(), detach: this);
    }
  }

  /// Releases the reference to the underlying ObjC object held by this wrapper.
  /// Throws a StateError if this wrapper doesn't currently hold a reference.
  void release() {
    if (_pendingRelease) {
      _pendingRelease = false;
      _release(_ptr.cast());
      _finalizer.detach(this);
    } else {
      throw StateError(
          'Released an ObjC object that was unowned or already released.');
    }
  }

  @override
  bool operator ==(Object other) {
    return other is _ObjCFinalizable && _ptr == other._ptr;
  }

  @override
  int get hashCode => _ptr.hashCode;

  /// Return a pointer to this object.
  Pointer<T> get pointer => _ptr;

  /// Retain a reference to this object and then return the pointer. This
  /// reference must be released when you are done with it. If you wrap this
  /// reference in another object, make sure to release it but not retain it:
  /// `castFromPointer(lib, pointer, retain: false, release: true)`
  Pointer<T> retainAndReturnPointer() {
    _retain(_ptr.cast());
    return _ptr;
  }

  NativeFinalizer get _finalizer => throw UnimplementedError();
  void _retain(Pointer<T> ptr) => throw UnimplementedError();
  void _release(Pointer<T> ptr) => throw UnimplementedError();
}

class ObjCObjectBase extends _ObjCFinalizable<c.ObjCObject> {
  ObjCObjectBase(super.ptr, {required super.retain, required super.release});

  static final _objectFinalizer = NativeFinalizer(
      Native.addressOf<NativeFunction<Void Function(Pointer<c.ObjCObject>)>>(
              c.objectRelease)
          .cast());

  @override
  NativeFinalizer get _finalizer => _objectFinalizer;

  @override
  void _retain(Pointer<c.ObjCObject> ptr) => c.objectRetain(ptr);

  @override
  void _release(Pointer<c.ObjCObject> ptr) => c.objectRelease(ptr);
}

class ObjCBlockBase extends _ObjCFinalizable<c.ObjCBlock> {
  ObjCBlockBase(super.ptr, {required super.retain, required super.release});

  static final _blockFinalizer = NativeFinalizer(
      Native.addressOf<NativeFunction<Void Function(Pointer<c.ObjCBlock>)>>(
              c.blockRelease)
          .cast());

  @override
  NativeFinalizer get _finalizer => _blockFinalizer;

  @override
  void _retain(Pointer<c.ObjCBlock> ptr) => c.blockCopy(ptr);

  @override
  void _release(Pointer<c.ObjCBlock> ptr) => c.blockRelease(ptr);
}

Pointer<c.ObjCBlockDesc> _newBlockDesc() {
  final desc = calloc.allocate<c.ObjCBlockDesc>(sizeOf<c.ObjCBlockDesc>());
  desc.ref.reserved = 0;
  desc.ref.size = sizeOf<c.ObjCBlock>();
  desc.ref.copy_helper = nullptr;
  desc.ref.dispose_helper = nullptr;
  desc.ref.signature = nullptr;
  return desc;
}

final _blockDesc = _newBlockDesc();

Pointer<c.ObjCBlock> newBlock(Pointer<Void> invoke, Pointer<Void> target) {
  final b = calloc.allocate<c.ObjCBlock>(sizeOf<c.ObjCBlock>());
  b.ref.isa = c.NSConcreteGlobalBlock;
  b.ref.flags = 0;
  b.ref.reserved = 0;
  b.ref.invoke = invoke;
  b.ref.target = target;
  b.ref.descriptor = _blockDesc;
  final copy = c.blockCopy(b.cast()).cast<c.ObjCBlock>();
  calloc.free(b);
  return copy;
}
