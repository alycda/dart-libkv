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

// C: store_exists
typedef StoreExistsC = Bool Function(Pointer<Store>, Pointer<Utf8>);
typedef StoreExistsDart = bool Function(Pointer<Store>, Pointer<Utf8>);
final _storeExists = kvlib
  .lookupFunction<StoreExistsC, StoreExistsDart>('store_exists');

// C: store_size
typedef StoreSizeC = Size Function(Pointer<Store>);
typedef StoreSizeDart = int Function(Pointer<Store>);
final _storeSize = kvlib
  .lookupFunction<StoreSizeC, StoreSizeDart>('store_size');

// C: store_clear
typedef StoreClearC = Void Function(Pointer<Store>);
typedef StoreClearDart = void Function(Pointer<Store>);
final _storeClear = kvlib
  .lookupFunction<StoreClearC, StoreClearDart>('store_clear');

// Dart Wrapper
class KeyValueStore {
  Pointer<Store>? _store;

  // constructor
  KeyValueStore() {
    _store = _storeCreate();
    if (_store == nullptr) {
      throw Exception('Failed to create store');
    }
  }

  /// Store a key-value pair (value as string)
  void put(String key, String value) {
    _checkStore();
    
    final keyPtr = key.toNativeUtf8();
    final valuePtr = value.toNativeUtf8();
    
    try {
      final result = _storePut(_store!, keyPtr, valuePtr.cast(), valuePtr.length);
      if (result != StoreError.ok) {
        throw Exception('store_put failed: ${StoreError.message(result)}');
      }
    } finally {
      malloc.free(keyPtr);
      malloc.free(valuePtr);
    }
  }

  /// Gets a value by key (returning a String)
  String? get(String key) {
    _checkStore();

    final keyPtr = key.toNativeUtf8();
    final valuePtrPtr = malloc.allocate<Pointer<Void>>(sizeOf<Pointer<Void>>());
    final sizePtr = malloc.allocate<Size>(sizeOf<Size>());
    
    try {
      final result = _storeGet(_store!, keyPtr, valuePtrPtr, sizePtr);
      
      if (result == StoreError.notFound) {
        return null;
      }
      
      if (result != StoreError.ok) {
        throw Exception('store_get failed: ${StoreError.message(result)}');
      }
      
      final valuePtr = valuePtrPtr.value;
      final size = sizePtr.value;
      
      // Copy bytes from C memory (don't free - it's owned by the store)
      final bytes = valuePtr.cast<Uint8>().asTypedList(size);
      return String.fromCharCodes(bytes);
    } finally {
      malloc.free(keyPtr);
      malloc.free(valuePtrPtr);
      malloc.free(sizePtr);
    }
  }

  /// Delete a key
  bool delete(String key) {
    _checkStore();

    final keyPtr = key.toNativeUtf8();
    try {
      final result = _storeDelete(_store!, keyPtr);
      return result == StoreError.ok;
    } finally {
      malloc.free(keyPtr);
    }
  }

  /// Check if Key exists
  bool exists(String key) {
    _checkStore();

    final keyPtr = key.toNativeUtf8();
    try {
      return _storeExists(_store!, keyPtr);
    } finally {
      malloc.free(keyPtr);
    }
  }

  /// Get number of entries
  int get size {
    _checkStore();

    return _storeSize(_store!);
  }

  /// Clear all entries
  void clear() {
    _checkStore();
    _storeClear(_store!);
  }

  /// Destroy and free resources
  void dispose() {
    if (_store != null && _store != nullptr) {
      _storeDestroy(_store!);
      _store = null;
    }
  }
  
  /// null safety check
  void _checkStore() {
    if (_store == null || _store == nullptr) {
      throw Exception('Store does not exist (disposed or never created)');
    }
  }
}

void runTests() {
  print('Running Dart FFI tests...\n');

  // Test 1: create_destroy & initial size
  final store = KeyValueStore();
  print('✓ Store created, initial size: ${store.size}');
  if (store.size != 0) {
    throw Exception('Expected size 0, got ${store.size}');
  }

  try {
    // Test 2: put_get_string
    print('\n✓ Testing put/get...');
    store.put('name', 'Alyssa');
    store.put('language', 'Dart');
    print('  name: ${store.get('name')}');
    print('  language: ${store.get('language')}');
    if (store.size != 2) {
      throw Exception('Expected size 2, got ${store.size}');
    }

    // Test 3: put_replace (overwrite existing key)
    print('\n✓ Testing key replacement...');
    store.put('language', 'Rust');
    final updated = store.get('language');
    print('  language updated: $updated');
    if (updated != 'Rust') {
      throw Exception('Expected "Rust", got "$updated"');
    }
    if (store.size != 2) {
      throw Exception('Size should still be 2 after replace');
    }

    // Test 4: get_notfound
    print('\n✓ Testing get non-existent key...');
    final missing = store.get('missing');
    print('  get("missing"): $missing');
    if (missing != null) {
      throw Exception('Expected null for missing key');
    }

    // Test 5: exists
    print('\n✓ Testing exists...');
    print('  exists("name"): ${store.exists('name')}');
    print('  exists("missing"): ${store.exists('missing')}');
    if (!store.exists('name') || store.exists('missing')) {
      throw Exception('exists() check failed');
    }

    // Test 6: delete
    print('\n✓ Testing delete...');
    final deleted = store.delete('language');
    print('  delete("language"): $deleted');
    print('  exists("language"): ${store.exists('language')}');
    if (!deleted || store.exists('language')) {
      throw Exception('Delete failed');
    }
    if (store.size != 1) {
      throw Exception('Expected size 1 after delete, got ${store.size}');
    }

    // Test 7: delete non-existent
    final notDeleted = store.delete('missing');
    print('  delete("missing"): $notDeleted');
    if (notDeleted) {
      throw Exception('Deleting non-existent key should return false');
    }

    // Test 8: multiple entries
    print('\n✓ Testing multiple entries...');
    for (int i = 0; i < 10; i++) {
      store.put('key$i', 'value$i');
    }
    print('  Added 10 entries, size: ${store.size}');
    if (store.size != 11) { // 1 (name) + 10 new
      throw Exception('Expected size 11, got ${store.size}');
    }

    // Verify all entries
    for (int i = 0; i < 10; i++) {
      final val = store.get('key$i');
      if (val != 'value$i') {
        throw Exception('Expected "value$i", got "$val"');
      }
    }
    print('  ✓ All entries verified');

    // Test 9: empty key
    print('\n✓ Testing empty key...');
    store.put('', 'empty key value');
    final emptyVal = store.get('');
    print('  get(""): $emptyVal');
    if (emptyVal != 'empty key value') {
      throw Exception('Empty key test failed');
    }

    // Test 10: long key
    print('\n✓ Testing long key...');
    final longKey = 'a' * 100;
    store.put(longKey, 'long key value');
    final longVal = store.get(longKey);
    if (longVal != 'long key value') {
      throw Exception('Long key test failed');
    }

    // Test 11: clear
    print('\n✓ Testing clear...');
    print('  Size before clear: ${store.size}');
    store.clear();
    print('  Size after clear: ${store.size}');
    if (store.size != 0) {
      throw Exception('Clear failed, size: ${store.size}');
    }
    if (store.exists('name')) {
      throw Exception('Keys still exist after clear');
    }

    // Test 12: use after clear
    print('\n✓ Testing use after clear...');
    store.put('new_key', 'new_value');
    if (store.size != 1) {
      throw Exception('Cannot use store after clear');
    }

  } finally {
    // Test 13: dispose
    print('\n✓ Testing dispose...');
    store.dispose();
    if (store._store != null) {
      throw Exception('Store pointer not nullified after dispose');
    }
    print('  Store destroyed successfully');
  }

  // Test 14: use after dispose
  print('\n✓ Testing use after dispose...');
  try {
    store.put('fail', 'should throw');
    throw Exception('Should not be able to use store after dispose');
  } catch (e) {
    print('  ✓ Correctly threw: $e');
  }

  print('\n🎉 All tests passed!');
}

void main(List<String> args) {
  if (args.contains('--test') || args.contains('-t')) {
    runTests();
  } else if (args.contains('--repl') || args.contains('-r')) {
    runRepl();
  } else {
    // Default: show usage and run tests
    print('Usage:');
    print('  dart src/kv_store.dart --test   # Run tests (default)');
    print('  dart src/kv_store.dart --repl   # Interactive REPL');
    print('');
    runTests();
  }
}

void runRepl() {
  print('===================================');
  print('  Dart FFI Key-Value Store REPL');
  print('===================================\n');

  final store = KeyValueStore();
  print('Store created. Type "help" for commands.\n');

  while (true) {
    stdout.write('kv> ');
    final input = stdin.readLineSync();

    if (input == null || input.trim().isEmpty) {
      continue;
    }

    final parts = input.trim().split(RegExp(r'\s+'));
    final command = parts[0].toLowerCase();

    try {
      switch (command) {
        case 'help':
          print('Available commands:');
          print('  put <key> <value>  - Store a key-value pair');
          print('  get <key>          - Retrieve a value by key');
          print('  delete <key>       - Delete a key');
          print('  exists <key>       - Check if key exists');
          print('  size               - Show number of entries');
          print('  clear              - Remove all entries');
          print('  list               - List all keys (not implemented in C lib)');
          print('  exit, quit         - Exit the REPL');
          print('  help               - Show this help message');

        case 'put':
          if (parts.length < 3) {
            print('Usage: put <key> <value>');
            break;
          }
          final key = parts[1];
          final value = parts.sublist(2).join(' ');
          store.put(key, value);
          print('✓ Stored: "$key" => "$value"');

        case 'get':
          if (parts.length < 2) {
            print('Usage: get <key>');
            break;
          }
          final key = parts[1];
          final value = store.get(key);
          if (value != null) {
            print('✓ "$key" => "$value"');
          } else {
            print('✗ Key "$key" not found');
          }

        case 'delete':
        case 'del':
          if (parts.length < 2) {
            print('Usage: delete <key>');
            break;
          }
          final key = parts[1];
          if (store.delete(key)) {
            print('✓ Deleted "$key"');
          } else {
            print('✗ Key "$key" not found');
          }

        case 'exists':
          if (parts.length < 2) {
            print('Usage: exists <key>');
            break;
          }
          final key = parts[1];
          final exists = store.exists(key);
          print(exists ? '✓ Key "$key" exists' : '✗ Key "$key" does not exist');

        case 'size':
          print('Store contains ${store.size} entries');

        case 'clear':
          store.clear();
          print('✓ Store cleared');

        case 'exit':
        case 'quit':
          print('Goodbye!');
          store.dispose();
          return;

        default:
          print('Unknown command: $command');
          print('Type "help" for available commands');
      }
    } catch (e) {
      print('✗ Error: $e');
    }

    print('');  // Empty line for readability
  }
}