import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

// Get absolute path to the library
//
// macOS has security features that prevent loading dynamic libraries using relative paths when running from certain contexts (like Nix). Need to use an absolute path instead.
String _getLibraryPath() {
  // Get the directory of this script
  final scriptDir = path.dirname(path.dirname(Platform.script.toFilePath()));
  final libName = Platform.isMacOS ? 'libkv.dylib' : 'libkv.so';
  return path.join(scriptDir, 'deps', 'kv', 'lib', libName);
}

final DynamicLibrary kvlib = DynamicLibrary.open(_getLibraryPath());

final class Store extends Opaque {}

class StoreError {
  static const int ok =        0;
  static const int noMem =    -1;
  static const int notFound = -2;
  static const int invalid =  -3;
  static const int exists =   -4;

  static String message(int code) {
    switch (code) {
      case ok:        return 'Success';
      case noMem:     return 'Out of memory';
      case notFound:  return 'Key not found';
      case invalid:   return 'Invalid parameter';
      case exists:    return 'Key already exists';
      default:        return 'Unknown error: $code';
    }
  }
}

// C: store_create
typedef StoreCreateC = Pointer<Store> Function();
typedef StoreCreateDart = Pointer<Store> Function();
final _storeCreate = kvlib
  .lookupFunction<StoreCreateC, StoreCreateDart>('store_create');

// C: store_destroy
typedef StoreDestroyC = Void Function(Pointer<Store>);
typedef StoreDestroyDart = void Function(Pointer<Store>);
final _storeDestroy = kvlib
  .lookupFunction<StoreDestroyC, StoreDestroyDart>('store_destroy');

// C: store_put
typedef StorePutC = Int32 Function(
  Pointer<Store>,         // store
  Pointer<Utf8>,          // key
  Pointer<Void>,          // value
  Size                    // value_size
);
typedef StorePutDart = int Function(
  Pointer<Store>,         // store
  Pointer<Utf8>,          // key
  Pointer<Void>,          // value
  int                     // value_size
);
final _storePut = kvlib
  .lookupFunction<StorePutC, StorePutDart>('store_put');

// C: store_get
typedef StoreGetC = Int32 Function(
  Pointer<Store>,         // store
  Pointer<Utf8>,          // key
  Pointer<Pointer<Void>>, // value_out
  Pointer<Size>           // value_size_out
);
typedef StoreGetDart = int Function(
  Pointer<Store>,         // store
  Pointer<Utf8>,          // key
  Pointer<Pointer<Void>>, // value_out
  Pointer<Size>           // value_size_out
);
final _storeGet = kvlib
  .lookupFunction<StoreGetC, StoreGetDart>('store_get');

// C: store_delete
typedef StoreDeleteC = Int32 Function(Pointer<Store>, Pointer<Utf8>);
typedef StoreDeleteDart = int Function(Pointer<Store>, Pointer<Utf8>);
final _storeDelete = kvlib
  .lookupFunction<StoreDeleteC, StoreDeleteDart>('store_delete');

void main() {
  final lib = kvlib;
  
  print('Hello, World!');
}