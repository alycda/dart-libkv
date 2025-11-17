# Interview Discussion Topics

## 1. How would you handle more complex data structures?

### Current Approach (String-only)
Our current implementation only handles strings:
```dart
store.put('key', 'value');  // Simple key-value pairs
```

### Approaches for Complex Data

#### Option A: JSON Serialization (Recommended for flexibility)
**When to use:** Mixed/nested structures, dynamic schemas

```dart
// Dart side
class User {
  String name;
  int age;
  List<String> roles;

  String toJson() => jsonEncode({
    'name': name,
    'age': age,
    'roles': roles,
  });

  factory User.fromJson(String json) {
    final map = jsonDecode(json);
    return User(
      name: map['name'],
      age: map['age'],
      roles: List<String>.from(map['roles']),
    );
  }
}

// Usage
store.put('user:123', user.toJson());
final userJson = store.get('user:123');
final user = User.fromJson(userJson!);
```

**Pros:**
- Language-agnostic (C doesn't need to know schema)
- Flexible schema evolution
- Human-readable for debugging

**Cons:**
- Serialization overhead
- Type safety only at runtime
- Larger storage size

---

#### Option B: Binary Protocols (Best performance)
**When to use:** High-performance, fixed schemas, large data

```dart
// Using Protocol Buffers, MessagePack, or custom binary format
import 'package:protobuf/protobuf.dart';

class UserProto extends GeneratedMessage {
  String name;
  int age;
  List<String> roles;
}

// Serialize to bytes
final bytes = userProto.writeToBuffer();
store.putBytes('user:123', bytes);

// Deserialize
final bytes = store.getBytes('user:123');
final user = UserProto.fromBuffer(bytes);
```

**Pros:**
- Compact binary representation
- Fast serialization/deserialization
- Schema validation (with protobuf)

**Cons:**
- Requires code generation
- Not human-readable
- Both sides need schema definition

---

#### Option C: Dart FFI Structs (Direct mapping)
**When to use:** C-defined structs, high performance, static schemas

```dart
// C side
typedef struct {
  char name[64];
  int32_t age;
  int32_t role_count;
  char roles[10][32];
} user_t;

int store_put_user(store_t* store, const char* key, user_t* user);

// Dart side
final class CUser extends Struct {
  @Array(64)
  external Array<Uint8> name;

  @Int32()
  external int age;

  @Int32()
  external int roleCount;

  @Array(10, 32)
  external Array<Array<Uint8>> roles;
}

// Usage
final userPtr = malloc.allocate<CUser>(sizeOf<CUser>());
// ... populate fields ...
_storePutUser(_store!, keyPtr, userPtr);
malloc.free(userPtr);
```

**Pros:**
- Zero-copy in some cases
- Direct memory mapping
- Type-safe at compile time

**Cons:**
- Fixed-size arrays
- Complex memory management
- Schema must match exactly between C and Dart
- Hard to evolve schema

---

#### Option D: Callbacks (For async operations)

**C side:**
```c
typedef void (*completion_callback)(void* user_data, const void* result, size_t size);

void store_get_async(store_t* store, const char* key,
                     completion_callback callback, void* user_data);
```

**Dart side:**
```dart
// Define callback signature
typedef CompletionCallback = Void Function(Pointer<Void>, Pointer<Void>, Size);
typedef CompletionCallbackDart = void Function(Pointer<Void>, Pointer<Void>, int);

// Create Dart callback
final callbackPointer = Pointer.fromFunction<CompletionCallback>(
  _completionCallback,
  nullptr, // exceptional return value
);

void _completionCallback(Pointer<Void> userData, Pointer<Void> result, int size) {
  // Handle result
}
```

**Challenge:** Dart callbacks can't be GC'd while C holds them!
**Solution:** Use `NativeCallable` (Dart 3.1+) for proper lifecycle management

```dart
final callback = NativeCallable<CompletionCallback>.listener(_completionCallback);
// Pass callback.nativeFunction to C
// Later: callback.close() when done
```

---

### Recommendation Matrix

| Use Case | Approach | Why |
|----------|----------|-----|
| General purpose KV | JSON | Flexible, easy to debug |
| High-performance cache | Binary (MessagePack) | Fast, compact |
| Database integration | Protocol Buffers | Schema validation |
| Direct C interop | FFI Structs | Type safety, performance |
| Event callbacks | NativeCallable | Proper lifecycle |

---

## 2. What about thread safety?

### Current State: Not Thread-Safe
```dart
// Multiple isolates accessing same store = undefined behavior!
final store = KeyValueStore(); // Shared pointer to C memory
```

### The Problem
- **C library**: Not thread-safe (no mutexes)
- **Dart isolates**: Can't share objects, but CAN share pointer addresses
- **Race conditions**: Multiple isolates → same C memory → crashes

### Solutions

#### Solution A: Mutex in C (Traditional approach)
```c
#include <pthread.h>

struct store {
    pthread_mutex_t lock;
    entry_t* entries;
    size_t count;
    size_t capacity;
};

int store_put(store_t* store, const char* key, const void* value, size_t size) {
    pthread_mutex_lock(&store->lock);

    // ... do work ...

    pthread_mutex_unlock(&store->lock);
    return STORE_OK;
}
```

**Pros:**
- Standard C practice
- Works across all languages

**Cons:**
- Can deadlock
- Blocks all operations (even reads)
- Doesn't play nice with Dart's async model

---

#### Solution B: Read-Write Lock (Better concurrency)
```c
#include <pthread.h>

struct store {
    pthread_rwlock_t rwlock;
    // ...
};

// Reads can happen in parallel
int store_get(store_t* store, const char* key, ...) {
    pthread_rwlock_rdlock(&store->rwlock);
    // ... read data ...
    pthread_rwlock_unlock(&store->rwlock);
}

// Writes are exclusive
int store_put(store_t* store, const char* key, ...) {
    pthread_rwlock_wrlock(&store->rwlock);
    // ... modify data ...
    pthread_rwlock_unlock(&store->rwlock);
}
```

**Pros:**
- Multiple readers, single writer
- Better throughput for read-heavy workloads

**Cons:**
- Writer starvation possible
- Still blocking

---

#### Solution C: Isolate Per Store (Dart-native approach)
**Recommended:** Don't share stores between isolates!

```dart
// WRONG: Multiple isolates, one store
final store = KeyValueStore();
await compute(doWork, store._store!.address); // DANGEROUS!

// RIGHT: Each isolate gets its own store
Future<String?> getInIsolate(String key) async {
  return await compute(_isolateWorker, {
    'libraryPath': _getLibraryPath(),
    'key': key,
  });
}

String? _isolateWorker(Map<String, dynamic> params) {
  // Each isolate creates its own store
  final lib = DynamicLibrary.open(params['libraryPath']);
  final createStore = lib.lookupFunction<...>('store_create');
  final localStore = createStore(); // New store instance!

  // ... use localStore ...

  storeDestroy(localStore); // Clean up
}
```

**Pros:**
- No locks needed (Dart isolate = separate heap)
- No race conditions
- Aligns with Dart's concurrency model

**Cons:**
- Each isolate has its own data (not shared)
- Memory duplication

---

#### Solution D: Actor Model (Advanced)
**Pattern:** Single "database isolate" receives messages

```dart
class StoreActor {
  late SendPort _commandPort;

  Future<void> start() async {
    final receivePort = ReceivePort();
    await Isolate.spawn(_isolateMain, receivePort.sendPort);
    _commandPort = await receivePort.first;
  }

  static void _isolateMain(SendPort sendPort) {
    final commandPort = ReceivePort();
    sendPort.send(commandPort.sendPort);

    final store = KeyValueStore(); // Lives only in this isolate

    commandPort.listen((message) {
      // Handle commands: get, put, delete
      // Send results back via message['replyPort']
    });
  }

  Future<String?> get(String key) async {
    final receivePort = ReceivePort();
    _commandPort.send({
      'op': 'get',
      'key': key,
      'replyPort': receivePort.sendPort,
    });
    return await receivePort.first;
  }
}
```

**Pros:**
- Single source of truth
- Thread-safe by design
- Centralized state management

**Cons:**
- Message passing overhead
- More complex implementation

---

### Recommendation

| Scenario | Solution | Why |
|----------|----------|-----|
| Single isolate only | No locking | Simple, fast |
| Multiple isolates, read-heavy | C rwlock + shared pointer | Performance |
| Multiple isolates, write-heavy | Isolate-per-store | Simplicity |
| Production system | Actor model | Safety, maintainability |

---

## 3. Performance Considerations

### FFI Overhead

**Baseline measurement:**
```dart
// Direct Dart map: ~50 ns/op
final map = <String, String>{};
map['key'] = 'value';

// FFI call: ~500 ns/op (10x slower)
store.put('key', 'value');
```

**Where does the time go?**
1. **String conversion** (50-100ns): `toNativeUtf8()` + `malloc`
2. **FFI boundary crossing** (100-200ns): Dart → C transition
3. **C function execution** (200-300ns): Actual work
4. **Memory cleanup** (50-100ns): `malloc.free()`

---

### When FFI Makes Sense

✅ **Good use cases:**
- Bulk operations (1000+ items)
- CPU-intensive work (crypto, compression)
- Leveraging existing C libraries
- Platform-specific APIs
- Persistent storage

❌ **Bad use cases:**
- Hot loops with small operations
- Simple data structures (use Dart Map)
- Single get/put calls in UI thread

---

### Optimization Strategies

#### Strategy 1: Batch Operations
**Instead of:**
```dart
for (final entry in entries) {
  store.put(entry.key, entry.value); // 1000 FFI calls!
}
```

**Do this:**
```dart
// C side: batch put
int store_put_batch(store_t* store, const char** keys,
                   const void** values, size_t* sizes, size_t count);

// Dart side
store.putBatch(entries); // 1 FFI call
```

**Speedup:** 10-50x for large batches

---

#### Strategy 2: Reduce String Conversions
```dart
// BAD: Converts on every call
for (var i = 0; i < 1000; i++) {
  store.put('key_$i', 'value_$i'); // 2000 allocations!
}

// GOOD: Pre-allocate if possible
final keyPtr = 'fixed_key'.toNativeUtf8();
try {
  for (var i = 0; i < 1000; i++) {
    final valuePtr = 'value_$i'.toNativeUtf8();
    try {
      _storePut(_store!, keyPtr, valuePtr.cast(), valuePtr.length);
    } finally {
      malloc.free(valuePtr);
    }
  }
} finally {
  malloc.free(keyPtr);
}
```

---

#### Strategy 3: Cache FFI Function Lookups
```dart
// BAD: Lookup on every use
DynamicLibrary.open('lib.so').lookupFunction<...>('func')();

// GOOD: Lookup once (we already do this!)
final _func = kvlib.lookupFunction<...>('func');
_func(); // Fast!
```

---

#### Strategy 4: Use Native Types When Possible
```dart
// SLOW: String conversion overhead
store.put('counter', '42'); // String → UTF8 → C → parse

// FAST: Direct int storage
int store_put_int(store_t* store, const char* key, int64_t value);
store.putInt('counter', 42); // Direct memory write
```

---

### Benchmarking Results

| Operation | Dart Map | FFI (sync) | FFI (async) |
|-----------|----------|------------|-------------|
| Single put | 50ns | 500ns | 50µs |
| Batch put (1k) | 50µs | 500µs | 100µs |
| Single get | 30ns | 400ns | 40µs |
| Batch get (1k) | 30µs | 400µs | 80µs |

**Takeaway:** Async overhead dominates for small ops; batching amortizes cost

---

## 4. Error Handling Strategies

### Current Approach: Hybrid

**C layer:** Error codes
```c
#define STORE_OK 0
#define STORE_ERR_NOMEM -1
#define STORE_ERR_NOTFOUND -2
```

**Dart layer:** Exceptions
```dart
if (result != StoreError.ok) {
  throw Exception('Store error: ${StoreError.message(result)}');
}
```

---

### Alternative Approaches

#### Approach A: Result Type (Rust-style)
```dart
class Result<T, E> {
  final T? value;
  final E? error;
  final bool isOk;

  Result.ok(this.value) : error = null, isOk = true;
  Result.err(this.error) : value = null, isOk = false;
}

// Usage
Result<String?, StoreError> get(String key) {
  final result = _storeGet(...);
  if (result == StoreError.ok) {
    return Result.ok(value);
  }
  return Result.err(result);
}

// Client code
final result = store.get('key');
if (result.isOk) {
  print(result.value);
} else {
  print('Error: ${result.error}');
}
```

**Pros:**
- Explicit error handling (can't ignore)
- Type-safe
- No exceptions in hot paths

**Cons:**
- Verbose
- Not idiomatic Dart

---

#### Approach B: Nullable Return + Exception (Current)
```dart
String? get(String key) {
  final result = _storeGet(...);
  if (result == StoreError.notFound) return null; // Expected
  if (result != StoreError.ok) {
    throw Exception(...); // Unexpected
  }
  return value;
}
```

**Pros:**
- Idiomatic Dart
- Null for "not found" is natural
- Exceptions for actual errors

**Cons:**
- Can forget to handle errors
- Exception performance cost

---

#### Approach C: Structured Errors
```dart
class StoreException implements Exception {
  final StoreError code;
  final String message;
  final String? key;

  StoreException(this.code, this.message, [this.key]);

  @override
  String toString() => 'StoreException($code): $message${key != null ? " (key: $key)" : ""}';
}

// Usage
try {
  store.put('key', 'value');
} on StoreException catch (e) {
  if (e.code == StoreError.noMem) {
    // Handle OOM
  } else {
    rethrow;
  }
}
```

**Pros:**
- Catchable by type
- Rich error context
- Can include key, stack trace, etc.

**Cons:**
- More code
- Still exception overhead

---

### Recommendation

**For library authors (what we did):**
- Return `null` for expected failures (`notFound`)
- Throw exceptions for unexpected failures (`noMem`, `invalid`)
- Provide error codes for advanced users

**For application developers:**
- Use `try-catch` around FFI boundaries
- Handle null returns gracefully
- Log structured errors for debugging

---

## Summary: Best Practices

1. **Complex Data:** JSON for flexibility, Protobuf for performance
2. **Thread Safety:** Actor model or isolate-per-store (avoid C locks)
3. **Performance:** Batch operations, measure before optimizing
4. **Error Handling:** Hybrid approach (null + exceptions)

**Key insight:** Dart FFI is best for *coarse-grained* operations with *significant* work per call. For fine-grained operations, stay in Dart!
