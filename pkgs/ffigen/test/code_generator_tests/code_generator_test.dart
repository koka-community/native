// Copyright (c) 2021, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:ffigen/src/code_generator.dart';
import 'package:ffigen/src/config_provider/config_types.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  const licenseHeader = '''
// Copyright (c) 2024, the Koka-Community. 
// 
// All rights reserved. Use of this source code is governed by a
// MIT-style license that can be found in the LICENSE file.
// Ffigen is adapted from dart's ffigen which is under a BSD Style License in the LICENSE file.
''';

  group('code_generator: ', () {
    @isTestGroup
    void withAndWithoutNative(
        String description, void Function(FfiNativeConfig) runTest,
        {bool skip = false}) {
      group(description, () {
        // test('without Native', () => runTest(FfiNativeConfig(enabled: false)));
        test('with Native',
            () => runTest(FfiNativeConfig(enabled: true, assetId: 'test')),
            skip: skip);
      });
    }

    withAndWithoutNative('Function Binding (primitives, pointers)',
        (nativeConfig) {
      final library = Library(
        name: 'Bindings',
        header: licenseHeader,
        bindings: [
          Func(
            ffiNativeConfig: nativeConfig,
            name: 'noParam',
            dartDoc: 'Just a test function\nheres another line',
            returnType: NativeType(
              SupportedNativeType.Int32,
            ),
          ),
          Func(
            ffiNativeConfig: nativeConfig,
            name: 'withPrimitiveParam',
            parameters: [
              Parameter(
                name: 'a',
                type: NativeType(
                  SupportedNativeType.Int32,
                ),
              ),
              Parameter(
                name: 'b',
                type: NativeType(
                  SupportedNativeType.Uint8,
                ),
              ),
            ],
            returnType: NativeType(
              SupportedNativeType.Char,
            ),
          ),
          Func(
            ffiNativeConfig: nativeConfig,
            name: 'withPointerParam',
            parameters: [
              Parameter(
                name: 'a',
                type: PointerType(
                  NativeType(
                    SupportedNativeType.Int32,
                  ),
                ),
              ),
              Parameter(
                name: 'b',
                type: PointerType(
                  PointerType(
                    NativeType(
                      SupportedNativeType.Uint8,
                    ),
                  ),
                ),
              ),
            ],
            returnType: PointerType(
              NativeType(
                SupportedNativeType.Double,
              ),
            ),
          ),
          Func(
            ffiNativeConfig: nativeConfig,
            isLeaf: true,
            name: 'leafFunc',
            dartDoc: 'A function with isLeaf: true',
            parameters: [
              Parameter(
                name: 'a',
                type: NativeType(
                  SupportedNativeType.Int32,
                ),
              ),
            ],
            returnType: NativeType(
              SupportedNativeType.Int32,
            ),
          ),
        ],
      );

      _matchLib(library, nativeConfig.enabled ? 'function' : 'function_dylib');
    });

    test(skip: true, 'Struct Binding (primitives, pointers)', () {
      final library = Library(
        name: 'Bindings',
        header: licenseHeader,
        bindings: [
          Struct(
            name: 'NoMember',
            dartDoc: 'Just a test struct\nheres another line',
          ),
          Struct(
            name: 'WithPrimitiveMember',
            members: [
              Member(
                name: 'a',
                type: NativeType(
                  SupportedNativeType.Int32,
                ),
              ),
              Member(
                name: 'b',
                type: NativeType(
                  SupportedNativeType.Double,
                ),
              ),
              Member(
                name: 'c',
                type: NativeType(
                  SupportedNativeType.Char,
                ),
              ),
            ],
          ),
          Struct(
            name: 'WithPointerMember',
            members: [
              Member(
                name: 'a',
                type: PointerType(
                  NativeType(
                    SupportedNativeType.Int32,
                  ),
                ),
              ),
              Member(
                name: 'b',
                type: PointerType(
                  PointerType(
                    NativeType(
                      SupportedNativeType.Double,
                    ),
                  ),
                ),
              ),
              Member(
                name: 'c',
                type: NativeType(
                  SupportedNativeType.Char,
                ),
              ),
            ],
          ),
          Struct(
            name: 'WithIntPtrUintPtr',
            members: [
              Member(
                name: 'a',
                type: PointerType(
                  NativeType(
                    SupportedNativeType.UintPtr,
                  ),
                ),
              ),
              Member(
                name: 'b',
                type: PointerType(
                  PointerType(
                    NativeType(
                      SupportedNativeType.IntPtr,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );

      _matchLib(library, 'struct');
    });

    test(skip: true, 'Function and Struct Binding (pointer to Struct)', () {
      final structSome = Struct(
        name: 'SomeStruct',
        members: [
          Member(
            name: 'a',
            type: NativeType(
              SupportedNativeType.Int32,
            ),
          ),
          Member(
            name: 'b',
            type: NativeType(
              SupportedNativeType.Double,
            ),
          ),
          Member(
            name: 'c',
            type: NativeType(
              SupportedNativeType.Char,
            ),
          ),
        ],
      );
      final library = Library(
        name: 'Bindings',
        header: licenseHeader,
        bindings: [
          structSome,
          Func(
            name: 'someFunc',
            parameters: [
              Parameter(
                name: 'some',
                type: PointerType(
                  PointerType(
                    structSome,
                  ),
                ),
              ),
            ],
            returnType: PointerType(
              structSome,
            ),
          ),
        ],
      );

      _matchLib(library, 'function_n_struct');
    });

    withAndWithoutNative('global (primitives, pointers, pointer to struct)',
        (nativeConfig) {
      final structSome = Struct(
        name: 'Some',
      );
      final emptyGlobalStruct = Struct(name: 'EmptyStruct');

      final library = Library(
        name: 'Bindings',
        header: licenseHeader,
        bindings: [
          Global(
            nativeConfig: nativeConfig,
            name: 'test1',
            type: NativeType(
              SupportedNativeType.Int32,
            ),
          ),
          Global(
            nativeConfig: nativeConfig,
            name: 'test2',
            type: PointerType(
              NativeType(
                SupportedNativeType.Float,
              ),
            ),
            constant: true,
          ),
          Global(
            nativeConfig: nativeConfig,
            name: 'test3',
            type: ConstantArray(
              10,
              NativeType(
                SupportedNativeType.Float,
              ),
              useArrayType: nativeConfig.enabled,
            ),
            constant: true,
          ),
          structSome,
          Global(
            nativeConfig: nativeConfig,
            name: 'test5',
            type: PointerType(
              structSome,
            ),
          ),
          emptyGlobalStruct,
          Global(
            nativeConfig: nativeConfig,
            name: 'globalStruct',
            type: emptyGlobalStruct,
          ),
        ],
      );
      _matchLib(library, nativeConfig.enabled ? 'global_native' : 'global');
    });

    test('constant', () {
      final library = Library(
        name: 'Bindings',
        header: '$licenseHeader',
        bindings: [
          Constant(
            name: 'test1',
            rawType: 'int',
            rawValue: '20',
          ),
          Constant(
            name: 'test2',
            rawType: 'float64',
            rawValue: '20.0',
          ),
        ],
      );
      _matchLib(library, 'constant');
    });

    test(skip: true, 'enum_class', () {
      final library = Library(
        name: 'Bindings',
        header: '$licenseHeader',
        bindings: [
          EnumClass(
            name: 'Constants',
            dartDoc: 'test line 1\ntest line 2',
            enumConstants: [
              EnumConstant(
                name: 'a',
                value: 10,
              ),
              EnumConstant(name: 'b', value: -1, dartDoc: 'negative'),
            ],
          ),
        ],
      );
      _matchLib(library, 'enumclass');
    });

    test(skip: true, 'Internal conflict resolution', () {
      final library = Library(
        name: 'init_dylib',
        header:
            '$licenseHeader\n// ignore_for_file: unused_element, camel_case_types, non_constant_identifier_names\n',
        bindings: [
          Func(
            name: 'test',
            returnType: NativeType(SupportedNativeType.Void),
          ),
          Func(
            name: '_test',
            returnType: NativeType(SupportedNativeType.Void),
          ),
          Func(
            name: '_c_test',
            returnType: NativeType(SupportedNativeType.Void),
          ),
          Func(
            name: '_dart_test',
            returnType: NativeType(SupportedNativeType.Void),
          ),
          Struct(
            name: '_Test',
            members: [
              Member(
                name: 'array',
                type: ConstantArray(
                  2,
                  NativeType(
                    SupportedNativeType.Int8,
                  ),
                  // This flag is ignored for struct fields, which always use
                  // inline arrays.
                  useArrayType: true,
                ),
              ),
            ],
          ),
          Struct(name: 'ArrayHelperPrefixCollisionTest'),
          Func(
            name: 'Test',
            returnType: NativeType(SupportedNativeType.Void),
          ),
          EnumClass(name: '_c_Test'),
          EnumClass(name: 'init_dylib'),
        ],
      );
      _matchLib(library, 'internal_conflict_resolution');
    });

    test(skip: true, 'Adds Native symbol on mismatch', () {
      final nativeConfig = FfiNativeConfig(enabled: true);
      final library = Library(
        name: 'init_dylib',
        header:
            '$licenseHeader\n// ignore_for_file: unused_element, camel_case_types, non_constant_identifier_names\n',
        bindings: [
          Func(
            ffiNativeConfig: nativeConfig,
            name: 'test',
            originalName: '_test',
            returnType: NativeType(SupportedNativeType.Void),
          ),
          Global(
            nativeConfig: nativeConfig,
            name: 'testField',
            originalName: '_testField',
            type: NativeType(SupportedNativeType.Int16),
          ),
        ],
      );
      _matchLib(library, 'native_symbol');
    });
    withAndWithoutNative('boolean', (nativeConfig) {
      final library = Library(
        name: 'Bindings',
        header: licenseHeader,
        bindings: [
          Func(
            ffiNativeConfig: nativeConfig,
            name: 'test1',
            returnType: BooleanType(),
            parameters: [
              Parameter(name: 'a', type: BooleanType()),
              Parameter(name: 'b', type: PointerType(BooleanType())),
            ],
          ),
          Struct(
            name: 'Test2',
            members: [
              Member(name: 'a', type: BooleanType()),
            ],
          ),
        ],
      );
      _matchLib(library, 'boolean');
    });
  });
  test(skip: true, 'sort bindings', () {
    final library = Library(
      name: 'Bindings',
      header: licenseHeader,
      sort: true,
      bindings: [
        Func(name: 'b', returnType: NativeType(SupportedNativeType.Void)),
        Func(name: 'a', returnType: NativeType(SupportedNativeType.Void)),
        Struct(name: 'D'),
        Struct(name: 'C'),
      ],
    );
    _matchLib(library, 'sort_bindings');
  });
  test(skip: true, 'Pack Structs', () {
    final library = Library(
      name: 'Bindings',
      header: licenseHeader,
      bindings: [
        Struct(name: 'NoPacking', pack: null, members: [
          Member(name: 'a', type: NativeType(SupportedNativeType.Char)),
        ]),
        Struct(name: 'Pack1', pack: 1, members: [
          Member(name: 'a', type: NativeType(SupportedNativeType.Char)),
        ]),
        Struct(name: 'Pack2', pack: 2, members: [
          Member(name: 'a', type: NativeType(SupportedNativeType.Char)),
        ]),
        Struct(name: 'Pack2', pack: 4, members: [
          Member(name: 'a', type: NativeType(SupportedNativeType.Char)),
        ]),
        Struct(name: 'Pack2', pack: 8, members: [
          Member(name: 'a', type: NativeType(SupportedNativeType.Char)),
        ]),
        Struct(name: 'Pack16', pack: 16, members: [
          Member(name: 'a', type: NativeType(SupportedNativeType.Char)),
        ]),
      ],
    );
    _matchLib(library, 'packed_structs');
  });
  test(skip: true, 'Union Bindings', () {
    final struct1 =
        Struct(name: 'Struct1', members: [Member(name: 'a', type: charType)]);
    final union1 =
        Union(name: 'Union1', members: [Member(name: 'a', type: charType)]);
    final library = Library(
      name: 'Bindings',
      header: licenseHeader,
      bindings: [
        struct1,
        union1,
        Union(name: 'EmptyUnion'),
        Union(name: 'Primitives', members: [
          Member(name: 'a', type: charType),
          Member(name: 'b', type: intType),
          Member(name: 'c', type: floatType),
          Member(name: 'd', type: doubleType),
        ]),
        Union(name: 'PrimitivesWithPointers', members: [
          Member(name: 'a', type: charType),
          Member(name: 'b', type: floatType),
          Member(name: 'c', type: PointerType(doubleType)),
          Member(name: 'd', type: PointerType(union1)),
          Member(name: 'd', type: PointerType(struct1)),
        ]),
        Union(name: 'WithArray', members: [
          Member(
            name: 'a',
            type: ConstantArray(10, charType, useArrayType: true),
          ),
          Member(
            name: 'b',
            type: ConstantArray(10, union1, useArrayType: true),
          ),
          Member(
            name: 'b',
            type: ConstantArray(10, struct1, useArrayType: true),
          ),
          Member(
            name: 'c',
            type: ConstantArray(10, PointerType(union1), useArrayType: true),
          ),
        ]),
      ],
    );
    _matchLib(library, 'unions');
  });
  test(skip: true, 'Typealias Bindings', () {
    final library = Library(
      name: 'Bindings',
      header:
          '$licenseHeader\n// ignore_for_file: non_constant_identifier_names\n',
      bindings: [
        Typealias(name: 'RawUnused', type: Struct(name: 'Struct1')),
        Struct(name: 'WithTypealiasStruct', members: [
          Member(
              name: 't',
              type: Typealias(
                  name: 'Struct2Typealias',
                  type: Struct(
                      name: 'Struct2',
                      members: [Member(name: 'a', type: doubleType)])))
        ]),
        Func(
            name: 'WithTypealiasStruct',
            returnType: PointerType(NativeFunc(FunctionType(
                returnType: NativeType(SupportedNativeType.Void),
                parameters: []))),
            parameters: [
              Parameter(
                  name: 't',
                  type: Typealias(
                      name: 'Struct3Typealias', type: Struct(name: 'Struct3')))
            ]),
      ],
    );
    _matchLib(library, 'typealias');
  });
}

/// Utility to match expected bindings to the generated bindings.
void _matchLib(Library lib, String testName) {
  matchLibraryWithExpected(lib, 'code_generator_test_${testName}_output.kk', [
    'test',
    'code_generator_tests',
    'expected_bindings',
    '_expected_${testName}_bindings.kk'
  ]);
}
