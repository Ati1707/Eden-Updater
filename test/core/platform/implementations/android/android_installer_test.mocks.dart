// Mocks generated by Mockito 5.4.6 from annotations
// in eden_updater/test/core/platform/implementations/android/android_installer_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i4;
import 'dart:convert' as _i5;
import 'dart:io' as _i2;
import 'dart:typed_data' as _i6;

import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i3;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: must_be_immutable
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeFile_0 extends _i1.SmartFake implements _i2.File {
  _FakeFile_0(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeUri_1 extends _i1.SmartFake implements Uri {
  _FakeUri_1(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeDirectory_2 extends _i1.SmartFake implements _i2.Directory {
  _FakeDirectory_2(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeFileSystemEntity_3 extends _i1.SmartFake
    implements _i2.FileSystemEntity {
  _FakeFileSystemEntity_3(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeDateTime_4 extends _i1.SmartFake implements DateTime {
  _FakeDateTime_4(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeRandomAccessFile_5 extends _i1.SmartFake
    implements _i2.RandomAccessFile {
  _FakeRandomAccessFile_5(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeIOSink_6 extends _i1.SmartFake implements _i2.IOSink {
  _FakeIOSink_6(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeFileStat_7 extends _i1.SmartFake implements _i2.FileStat {
  _FakeFileStat_7(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

/// A class which mocks [File].
///
/// See the documentation for Mockito's code generation for more information.
class MockFile extends _i1.Mock implements _i2.File {
  MockFile() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i2.File get absolute =>
      (super.noSuchMethod(
            Invocation.getter(#absolute),
            returnValue: _FakeFile_0(this, Invocation.getter(#absolute)),
          )
          as _i2.File);

  @override
  String get path =>
      (super.noSuchMethod(
            Invocation.getter(#path),
            returnValue: _i3.dummyValue<String>(this, Invocation.getter(#path)),
          )
          as String);

  @override
  Uri get uri =>
      (super.noSuchMethod(
            Invocation.getter(#uri),
            returnValue: _FakeUri_1(this, Invocation.getter(#uri)),
          )
          as Uri);

  @override
  bool get isAbsolute =>
      (super.noSuchMethod(Invocation.getter(#isAbsolute), returnValue: false)
          as bool);

  @override
  _i2.Directory get parent =>
      (super.noSuchMethod(
            Invocation.getter(#parent),
            returnValue: _FakeDirectory_2(this, Invocation.getter(#parent)),
          )
          as _i2.Directory);

  @override
  _i4.Future<_i2.File> create({
    bool? recursive = false,
    bool? exclusive = false,
  }) =>
      (super.noSuchMethod(
            Invocation.method(#create, [], {
              #recursive: recursive,
              #exclusive: exclusive,
            }),
            returnValue: _i4.Future<_i2.File>.value(
              _FakeFile_0(
                this,
                Invocation.method(#create, [], {
                  #recursive: recursive,
                  #exclusive: exclusive,
                }),
              ),
            ),
          )
          as _i4.Future<_i2.File>);

  @override
  void createSync({bool? recursive = false, bool? exclusive = false}) =>
      super.noSuchMethod(
        Invocation.method(#createSync, [], {
          #recursive: recursive,
          #exclusive: exclusive,
        }),
        returnValueForMissingStub: null,
      );

  @override
  _i4.Future<_i2.File> rename(String? newPath) =>
      (super.noSuchMethod(
            Invocation.method(#rename, [newPath]),
            returnValue: _i4.Future<_i2.File>.value(
              _FakeFile_0(this, Invocation.method(#rename, [newPath])),
            ),
          )
          as _i4.Future<_i2.File>);

  @override
  _i2.File renameSync(String? newPath) =>
      (super.noSuchMethod(
            Invocation.method(#renameSync, [newPath]),
            returnValue: _FakeFile_0(
              this,
              Invocation.method(#renameSync, [newPath]),
            ),
          )
          as _i2.File);

  @override
  _i4.Future<_i2.FileSystemEntity> delete({bool? recursive = false}) =>
      (super.noSuchMethod(
            Invocation.method(#delete, [], {#recursive: recursive}),
            returnValue: _i4.Future<_i2.FileSystemEntity>.value(
              _FakeFileSystemEntity_3(
                this,
                Invocation.method(#delete, [], {#recursive: recursive}),
              ),
            ),
          )
          as _i4.Future<_i2.FileSystemEntity>);

  @override
  void deleteSync({bool? recursive = false}) => super.noSuchMethod(
    Invocation.method(#deleteSync, [], {#recursive: recursive}),
    returnValueForMissingStub: null,
  );

  @override
  _i4.Future<_i2.File> copy(String? newPath) =>
      (super.noSuchMethod(
            Invocation.method(#copy, [newPath]),
            returnValue: _i4.Future<_i2.File>.value(
              _FakeFile_0(this, Invocation.method(#copy, [newPath])),
            ),
          )
          as _i4.Future<_i2.File>);

  @override
  _i2.File copySync(String? newPath) =>
      (super.noSuchMethod(
            Invocation.method(#copySync, [newPath]),
            returnValue: _FakeFile_0(
              this,
              Invocation.method(#copySync, [newPath]),
            ),
          )
          as _i2.File);

  @override
  _i4.Future<int> length() =>
      (super.noSuchMethod(
            Invocation.method(#length, []),
            returnValue: _i4.Future<int>.value(0),
          )
          as _i4.Future<int>);

  @override
  int lengthSync() =>
      (super.noSuchMethod(Invocation.method(#lengthSync, []), returnValue: 0)
          as int);

  @override
  _i4.Future<DateTime> lastAccessed() =>
      (super.noSuchMethod(
            Invocation.method(#lastAccessed, []),
            returnValue: _i4.Future<DateTime>.value(
              _FakeDateTime_4(this, Invocation.method(#lastAccessed, [])),
            ),
          )
          as _i4.Future<DateTime>);

  @override
  DateTime lastAccessedSync() =>
      (super.noSuchMethod(
            Invocation.method(#lastAccessedSync, []),
            returnValue: _FakeDateTime_4(
              this,
              Invocation.method(#lastAccessedSync, []),
            ),
          )
          as DateTime);

  @override
  _i4.Future<dynamic> setLastAccessed(DateTime? time) =>
      (super.noSuchMethod(
            Invocation.method(#setLastAccessed, [time]),
            returnValue: _i4.Future<dynamic>.value(),
          )
          as _i4.Future<dynamic>);

  @override
  void setLastAccessedSync(DateTime? time) => super.noSuchMethod(
    Invocation.method(#setLastAccessedSync, [time]),
    returnValueForMissingStub: null,
  );

  @override
  _i4.Future<DateTime> lastModified() =>
      (super.noSuchMethod(
            Invocation.method(#lastModified, []),
            returnValue: _i4.Future<DateTime>.value(
              _FakeDateTime_4(this, Invocation.method(#lastModified, [])),
            ),
          )
          as _i4.Future<DateTime>);

  @override
  DateTime lastModifiedSync() =>
      (super.noSuchMethod(
            Invocation.method(#lastModifiedSync, []),
            returnValue: _FakeDateTime_4(
              this,
              Invocation.method(#lastModifiedSync, []),
            ),
          )
          as DateTime);

  @override
  _i4.Future<dynamic> setLastModified(DateTime? time) =>
      (super.noSuchMethod(
            Invocation.method(#setLastModified, [time]),
            returnValue: _i4.Future<dynamic>.value(),
          )
          as _i4.Future<dynamic>);

  @override
  void setLastModifiedSync(DateTime? time) => super.noSuchMethod(
    Invocation.method(#setLastModifiedSync, [time]),
    returnValueForMissingStub: null,
  );

  @override
  _i4.Future<_i2.RandomAccessFile> open({
    _i2.FileMode? mode = _i2.FileMode.read,
  }) =>
      (super.noSuchMethod(
            Invocation.method(#open, [], {#mode: mode}),
            returnValue: _i4.Future<_i2.RandomAccessFile>.value(
              _FakeRandomAccessFile_5(
                this,
                Invocation.method(#open, [], {#mode: mode}),
              ),
            ),
          )
          as _i4.Future<_i2.RandomAccessFile>);

  @override
  _i2.RandomAccessFile openSync({_i2.FileMode? mode = _i2.FileMode.read}) =>
      (super.noSuchMethod(
            Invocation.method(#openSync, [], {#mode: mode}),
            returnValue: _FakeRandomAccessFile_5(
              this,
              Invocation.method(#openSync, [], {#mode: mode}),
            ),
          )
          as _i2.RandomAccessFile);

  @override
  _i4.Stream<List<int>> openRead([int? start, int? end]) =>
      (super.noSuchMethod(
            Invocation.method(#openRead, [start, end]),
            returnValue: _i4.Stream<List<int>>.empty(),
          )
          as _i4.Stream<List<int>>);

  @override
  _i2.IOSink openWrite({
    _i2.FileMode? mode = _i2.FileMode.write,
    _i5.Encoding? encoding = const _i5.Utf8Codec(),
  }) =>
      (super.noSuchMethod(
            Invocation.method(#openWrite, [], {
              #mode: mode,
              #encoding: encoding,
            }),
            returnValue: _FakeIOSink_6(
              this,
              Invocation.method(#openWrite, [], {
                #mode: mode,
                #encoding: encoding,
              }),
            ),
          )
          as _i2.IOSink);

  @override
  _i4.Future<_i6.Uint8List> readAsBytes() =>
      (super.noSuchMethod(
            Invocation.method(#readAsBytes, []),
            returnValue: _i4.Future<_i6.Uint8List>.value(_i6.Uint8List(0)),
          )
          as _i4.Future<_i6.Uint8List>);

  @override
  _i6.Uint8List readAsBytesSync() =>
      (super.noSuchMethod(
            Invocation.method(#readAsBytesSync, []),
            returnValue: _i6.Uint8List(0),
          )
          as _i6.Uint8List);

  @override
  _i4.Future<String> readAsString({
    _i5.Encoding? encoding = const _i5.Utf8Codec(),
  }) =>
      (super.noSuchMethod(
            Invocation.method(#readAsString, [], {#encoding: encoding}),
            returnValue: _i4.Future<String>.value(
              _i3.dummyValue<String>(
                this,
                Invocation.method(#readAsString, [], {#encoding: encoding}),
              ),
            ),
          )
          as _i4.Future<String>);

  @override
  String readAsStringSync({_i5.Encoding? encoding = const _i5.Utf8Codec()}) =>
      (super.noSuchMethod(
            Invocation.method(#readAsStringSync, [], {#encoding: encoding}),
            returnValue: _i3.dummyValue<String>(
              this,
              Invocation.method(#readAsStringSync, [], {#encoding: encoding}),
            ),
          )
          as String);

  @override
  _i4.Future<List<String>> readAsLines({
    _i5.Encoding? encoding = const _i5.Utf8Codec(),
  }) =>
      (super.noSuchMethod(
            Invocation.method(#readAsLines, [], {#encoding: encoding}),
            returnValue: _i4.Future<List<String>>.value(<String>[]),
          )
          as _i4.Future<List<String>>);

  @override
  List<String> readAsLinesSync({
    _i5.Encoding? encoding = const _i5.Utf8Codec(),
  }) =>
      (super.noSuchMethod(
            Invocation.method(#readAsLinesSync, [], {#encoding: encoding}),
            returnValue: <String>[],
          )
          as List<String>);

  @override
  _i4.Future<_i2.File> writeAsBytes(
    List<int>? bytes, {
    _i2.FileMode? mode = _i2.FileMode.write,
    bool? flush = false,
  }) =>
      (super.noSuchMethod(
            Invocation.method(
              #writeAsBytes,
              [bytes],
              {#mode: mode, #flush: flush},
            ),
            returnValue: _i4.Future<_i2.File>.value(
              _FakeFile_0(
                this,
                Invocation.method(
                  #writeAsBytes,
                  [bytes],
                  {#mode: mode, #flush: flush},
                ),
              ),
            ),
          )
          as _i4.Future<_i2.File>);

  @override
  void writeAsBytesSync(
    List<int>? bytes, {
    _i2.FileMode? mode = _i2.FileMode.write,
    bool? flush = false,
  }) => super.noSuchMethod(
    Invocation.method(#writeAsBytesSync, [bytes], {#mode: mode, #flush: flush}),
    returnValueForMissingStub: null,
  );

  @override
  _i4.Future<_i2.File> writeAsString(
    String? contents, {
    _i2.FileMode? mode = _i2.FileMode.write,
    _i5.Encoding? encoding = const _i5.Utf8Codec(),
    bool? flush = false,
  }) =>
      (super.noSuchMethod(
            Invocation.method(
              #writeAsString,
              [contents],
              {#mode: mode, #encoding: encoding, #flush: flush},
            ),
            returnValue: _i4.Future<_i2.File>.value(
              _FakeFile_0(
                this,
                Invocation.method(
                  #writeAsString,
                  [contents],
                  {#mode: mode, #encoding: encoding, #flush: flush},
                ),
              ),
            ),
          )
          as _i4.Future<_i2.File>);

  @override
  void writeAsStringSync(
    String? contents, {
    _i2.FileMode? mode = _i2.FileMode.write,
    _i5.Encoding? encoding = const _i5.Utf8Codec(),
    bool? flush = false,
  }) => super.noSuchMethod(
    Invocation.method(
      #writeAsStringSync,
      [contents],
      {#mode: mode, #encoding: encoding, #flush: flush},
    ),
    returnValueForMissingStub: null,
  );

  @override
  _i4.Future<bool> exists() =>
      (super.noSuchMethod(
            Invocation.method(#exists, []),
            returnValue: _i4.Future<bool>.value(false),
          )
          as _i4.Future<bool>);

  @override
  bool existsSync() =>
      (super.noSuchMethod(
            Invocation.method(#existsSync, []),
            returnValue: false,
          )
          as bool);

  @override
  _i4.Future<String> resolveSymbolicLinks() =>
      (super.noSuchMethod(
            Invocation.method(#resolveSymbolicLinks, []),
            returnValue: _i4.Future<String>.value(
              _i3.dummyValue<String>(
                this,
                Invocation.method(#resolveSymbolicLinks, []),
              ),
            ),
          )
          as _i4.Future<String>);

  @override
  String resolveSymbolicLinksSync() =>
      (super.noSuchMethod(
            Invocation.method(#resolveSymbolicLinksSync, []),
            returnValue: _i3.dummyValue<String>(
              this,
              Invocation.method(#resolveSymbolicLinksSync, []),
            ),
          )
          as String);

  @override
  _i4.Future<_i2.FileStat> stat() =>
      (super.noSuchMethod(
            Invocation.method(#stat, []),
            returnValue: _i4.Future<_i2.FileStat>.value(
              _FakeFileStat_7(this, Invocation.method(#stat, [])),
            ),
          )
          as _i4.Future<_i2.FileStat>);

  @override
  _i2.FileStat statSync() =>
      (super.noSuchMethod(
            Invocation.method(#statSync, []),
            returnValue: _FakeFileStat_7(
              this,
              Invocation.method(#statSync, []),
            ),
          )
          as _i2.FileStat);

  @override
  _i4.Stream<_i2.FileSystemEvent> watch({
    int? events = 15,
    bool? recursive = false,
  }) =>
      (super.noSuchMethod(
            Invocation.method(#watch, [], {
              #events: events,
              #recursive: recursive,
            }),
            returnValue: _i4.Stream<_i2.FileSystemEvent>.empty(),
          )
          as _i4.Stream<_i2.FileSystemEvent>);
}
