---
title: Dart FFI with libkv
sub_title: Building Safe C Bindings in Dart
author: Alyssa Evans
---

# Overview

Building Dart FFI bindings for a C key-value store library

## Steps

1. build dylib instead of static c lib
2. create FFI bindings
3. Dart wrapper API
4. Testing
5. Challenges & Key Takeaways
6. Bonus: Interactive REPL + CSV Export
7. Next Steps: Blocking I/O

<!--
**Topics:**
- FFI architecture & data flow
- Memory management & safety
- Lessons learned
- CSV export with C iteration support
- Handling blocking I/O with isolates -->

<!-- end_slide -->

# 1. Building a Dynamic Library

**Three key changes to the Makefile:**

1. Add `-fPIC` (Position Independent Code) to CFLAGS
2. Change library name from `.a` to `.dylib`
3. Use `-shared` flag when linking

```diff
# Compiler and flags
CC = gcc
- CFLAGS = -Wall -Wextra -Werror -std=c11 -pedantic -D_POSIX_C_SOURCE=200809L
+ CFLAGS = -Wall -Wextra -Werror -std=c11 -pedantic -D_POSIX_C_SOURCE=200809L -fPIC
```

```diff
# Library
- LIB_NAME = libkv.a
+ LIB_NAME = libkv.dylib
```

```diff
# Build library
$(LIB): $(OBJECTS) | $(LIB_DIR)
-     ar rcs $@ $^
+     $(CC) -shared -o $@ $^ $(LDFLAGS)
```

**Why?** Dart FFI requires dynamic libraries, not static archives.

<!-- end_slide -->

<!-- skip_slide -->

# 1.1 Loading the Library: Cross-Platform Paths

**Challenge:** Need to load the library on both macOS and Linux

<!-- NOTE:
language is set to `java` because presenterm doesn't support `dart` and this provides reasonable syntax highlighting -->
```file
path: src/kv_store.dart
language: java
start_line: 6
end_line: 16
```

**Key decisions:**
- Use **absolute paths** (relative paths fail in Nix/hardened environments)
- Detect platform at **runtime** (`Platform.isMacOS`)
- Match Makefile platform detection for `.dylib` vs `.so`

<!-- end_slide -->

# 2. FFI Foundations: Opaque Types

**Background**  
The C library exposes `store_t*`, an opaque pointer to an internal struct whose layout is hidden from callers.

**Dart Mapping**  
In Dart we represent this with an `Opaque` subclass:

<!-- NOTE:
language is set to `java` because presenterm doesn't support `dart` -->
```java
final class Store extends Opaque {}
```

**Why use an opaque type?**

- The internal structure isn’t needed in Dart code.
- Memory management remains the responsibility of the C library.
- Dart only needs to hold and forward the pointer.

<!-- end_slide -->

# 2.1 Error Handling Strategy

**C library returns error codes** (int: 0 = success, negative = error)

**in Dart:**
<!-- NOTE:
language is set to `kotlin` because presenterm doesn't support `dart` and this provides reasonable syntax highlighting FOR THIS CODE SNIPPET -->
```file
path: src/kv_store.dart
language: kotlin
start_line: 22
end_line: 39
```

**in C:**
```file
path: deps/kv/include/store.h
language: c
start_line: 13
end_line: 19
```

**Design decision:** Keep C-style codes in Dart, convert to messages when needed
- Later we'll throw exceptions in the wrapper class
- But FFI bindings stay close to C

<!-- end_slide -->

# 2.2 Type Mappings: C ↔ Dart

| C Type | Dart FFI Type (C signature) | Dart Type (Dart signature) |
|--------|----------------------------|---------------------------|
| `void*` | `Pointer<Void>` | `Pointer<Void>` |
| `char*` | `Pointer<Utf8>` | `Pointer<Utf8>` |
| `size_t` | `Size` | `int` |
| `int` | `Int32` | `int` |
| `bool` | `Bool` | `bool` |
| `void` | `Void` | `void` |
| `struct store*` | `Pointer<Store>` | `Pointer<Store>` |

**Note:** `Size` is platform-dependent (32-bit or 64-bit)

<!-- end_slide -->

# 2.3 Data Flow: Dart → C

```
┌──────────────────────────────┐
│ Dart Application Layer       │
│  store.put("name", "Alyssa") │
└──────────────────┬───────────┘
                   │
┌──────────────────▼─────────────────────┐
│ Dart FFI Binding Layer                 │
│  - Convert Dart String → Pointer<Utf8> │
│  - Allocate memory (malloc)            │
│  - Call C function                     │
└──────────────────┬─────────────────────┘
                   │
┌──────────────────▼────────────────────┐
│ C Library (libkv.dylib)               │
│  - store_put(store, key, value, size) │
│  - Allocate & copy data in C heap     │
└───────────────────────────────────────┘
```

<!-- end_slide -->

# 2.4 Data Flow: C → Dart

```
┌───────────────────────────────┐
│ C Library Returns             │
│  - Pointer to C-owned memory  │
│  - Size of data               │
└──────────────────┬────────────┘
                   │
┌──────────────────▼────────────────────────────┐
│ Dart FFI Binding Layer                        │
│  - asTypedList() to view C memory             │
│  - String.fromCharCodes() to copy data        │
│  - Free allocated Dart pointers (NOT C data!) │
└──────────────────┬────────────────────────────┘
                   │
┌──────────────────▼─────────────────┐
│ Dart Application                   │
│  String? value = store.get("name") │
└────────────────────────────────────┘
```

<!-- end_slide -->

# 2.5 Memory Management: Critical Concepts

**Two Memory Spaces:**
1. **Dart Heap** - Managed by Dart GC
2. **C Heap** - Manual malloc/free

**Who owns what?**

| Memory | Allocated By | Freed By | Example |
|--------|--------------|----------|---------|
| Key pointer | Dart (toNativeUtf8) | Dart (malloc.free) | `keyPtr` |
| Value pointer | Dart (toNativeUtf8) | Dart (malloc.free) | `valuePtr` |
| C store data | C (malloc) | C (store_destroy) | Internal entries |
| Returned value | C (existing) | C (never!) | `store_get` result |

<!-- end_slide -->

# 2.6 Memory Safety Pattern

<!-- NOTE:
language is set to `java` because presenterm doesn't support `dart` -->
**The Dart Side:**
```file
path: src/kv_store.dart
language: java
start_line: 146
end_line: 161
```

**The C Side:**

!! TODO !!

<!-- ```file 
path: deps/kv/src/store.c
language: c
start_line: 100
end_line: 114
```

```c
int store_get(store_t* store, const char* key,
              const void** value_out, size_t* value_size_out) {
    *value_out = store->entries[i].value;  // ← C owns this!
    *value_size_out = store->entries[i].value_size;
    return STORE_OK;
}
``` -->

**Critical:** Dart must NOT free the returned pointer - C library owns it

<!-- end_slide -->

# 3. Dart Wrapper: Ergonomic API

**Goal:** Hide FFI complexity, provide idiomatic Dart API

**Core pattern:**
- Constructor validates store creation
- Every method checks store validity (`_checkStore()`)
- All allocations cleaned up in `finally` blocks
- Error codes → Dart exceptions

<!-- end_slide -->

# 3.1 Constructor & Lifecycle

<!-- NOTE:
language is set to `java` because presenterm doesn't support `dart` -->
```file
path: src/kv_store.dart
language: java
start_line: 133
end_line: 143
```

<!-- NOTE:
language is set to `java` because presenterm doesn't support `dart` -->
```file
path: src/kv_store.dart
language: java
start_line: 377
end_line: 382
```

<!-- NOTE:
language is set to `java` because presenterm doesn't support `dart` -->
```file
path: src/kv_store.dart
language: java
start_line: 369
end_line: 375
```

**Lifecycle management:**
- Constructor throws if creation fails
- `_checkStore()` prevents use-after-dispose
- `dispose()` cleans up and nullifies pointer

<!-- end_slide -->

# 3.2 Writing Data: put()

<!-- NOTE:
language is set to `java` because presenterm doesn't support `dart` -->
```file
path: src/kv_store.dart
language: java
start_line: 146
end_line: 161
```

**Key patterns:**
- `toNativeUtf8()` allocates → **must free**
- `try/finally` ensures cleanup even on exception
- Error codes converted to exceptions with helpful messages

<!-- end_slide -->

# 3.3 Reading Data: get()

<!-- NOTE:
language is set to `java` because presenterm doesn't support `dart` -->
```file
path: src/kv_store.dart
language: java
start_line: 163
end_line: 193
```

**Critical distinction:**
- `keyPtr`, `valuePtrPtr`, `sizePtr` → Dart allocated → **must free**
- `valuePtr.value` → C allocated → **never free!**
- Use `asTypedList()` to view C memory, `String.fromCharCodes()` to copy

<!-- end_slide -->

# 3.4 Other Methods

All follow the same pattern:

**Simple operations:**
- `delete(key)` - returns bool, same try/finally pattern
- `exists(key)` - returns bool, no error handling needed
- `size` - getter, no memory allocation needed
- `clear()` - void, no memory allocation needed

```file
path: src/kv_store.dart
language: java
start_line: 195
end_line: 206
```

<!-- end_slide -->

# 4. Testing & Validation

**Comprehensive test coverage in main():**
- All CRUD operations (put, get, delete, exists, clear)
- Edge cases (empty keys, long keys, missing keys, key replacement)
- Multiple entries (10+ items)
- Lifecycle (use after clear, use after dispose)
- Memory leak detection (size checks throughout)

**Mirrors C test suite** (`deps/kv/tests/test_store.c`)
- Same test scenarios where applicable
- String-only vs C's binary data (design choice)

```bash
$ just run
Running Dart FFI tests...
✓ Store created, initial size: 0
✓ Testing put/get...
✓ Testing key replacement...
...
🎉 All tests passed!
```

<!-- end_slide -->

# 5. Challenges & Lessons Learned

**1. Relative paths don't work with Nix/hardened programs**
- Solution: Use `Platform.script.toFilePath()` for absolute paths
- Required adding `path` package

**2. Static vs Dynamic libraries**
- `.a` files cannot be used with Dart FFI
- Must build `.dylib` (macOS) or `.so` (Linux)
- Added `-fPIC` and `-shared` to Makefile

**3. Memory ownership clarity**
- Document who allocates and who frees
- Use try/finally religiously
- Never free C-owned memory from Dart

<!-- end_slide -->

# 5. Challenges & Lessons Learned (cont.)

**4. String encoding**
- `toNativeUtf8()` allocates - must free!
- `toNativeUtf8().length` includes null terminator
- C expects null-terminated strings

**5. Pointer-to-pointer pattern**
```java
final ptrPtr = malloc.allocate<Pointer<Void>>(sizeOf<Pointer<Void>>());
final result = _storeGet(store, key, ptrPtr, sizePtr);
final actualPtr = ptrPtr.value;  // Dereference
```

**6. Testing disposal**
- No need to compare `KeyValueStore` object with `nullptr` (Dart type safety)
- DO need to check internal `_store` pointer
- Or verify methods throw after dispose

<!-- end_slide -->

# 5.1 Key Takeaways

**Safety First:**
- Always use try/finally for malloc'd pointers
- Never free memory you don't own
- Check for null/nullptr before use

**Architecture:**
- Clear separation: App → Bindings → C
- Wrapper class for ergonomic API
- Type safety through Dart's strong typing

**Testing:**
- Comprehensive edge case coverage
- Lifecycle validation is critical
- Memory leak detection through size checks

<!-- end_slide -->

# 6. Bonus: Interactive REPL

**Beyond tests - a usable demo!**

Added an interactive Read-Eval-Print Loop for hands-on exploration:

```bash
$ just repl
===================================
  Dart FFI Key-Value Store REPL
===================================

Store created. Type "help" for commands.

kv> put name Alyssa
✓ Stored: "name" => "Alyssa"

kv> get name
✓ "name" => "Alyssa"

kv> size
Store contains 1 entries
```

<!-- end_slide -->

# 6.1 REPL Implementation

**Command-line argument parsing:**
<!-- ```file
path: src/kv_store.dart
language: java
start_line: 369
end_line: 382
``` -->

```java
void main(List<String> args) {
  if (args.contains('--test') || args.contains('-t')) {
    runTests();
  } else if (args.contains('--repl') || args.contains('-r')) {
    runRepl();
  } else {
    // Default: show usage and run tests
    runTests();
  }
}
```

**Available commands:**
- `put <key> <value>` - Store data
- `get <key>` - Retrieve data
- `delete <key>` - Remove entry
- `exists <key>` - Check existence
- `list` - List all keys
- `size` - Show entry count
- `export [file]` - Export to CSV (console or file)
- `clear` - Clear all
- `exit/quit` - Exit cleanly (calls dispose!)

<!-- end_slide -->

# 6.2 CSV Export Feature

**New capability: Export data to CSV format**

```bash
kv> put name Alyssa
✓ Stored: "name" => "Alyssa"

kv> put role "Software Engineer"
✓ Stored: "role" => "Software Engineer"

kv> list
Keys (2):
  - name
  - role

kv> export
key,value
name,Alyssa
role,"Software Engineer"

kv> export data.csv
✓ Exported to "data.csv"
```

**Features:** Proper CSV escaping (commas, quotes), iteration via new C function

<!-- end_slide -->

# 7. Next Steps: Blocking I/O

**The Challenge:**
Many C functions block (network I/O, disk I/O, database calls)

**The Problem:**
Dart is single-threaded by default - blocking FFI calls freeze the event loop!

```java
// This BLOCKS the main thread for 500ms
final value = store.getBlocking('key', delayMs: 500);
// UI is frozen during this time!
```

**Real-world examples:**
- Network requests (HTTP, database queries)
- File I/O on slow disks
- Cryptographic operations
- Hardware communication

<!-- end_slide -->

# 7.1 Solution 1: Isolates

**Run blocking calls in background isolates**

```java
// Non-blocking - runs in separate isolate
Future<String?> getBlockingAsync(String key, {int delayMs = 1000}) async {
  return await compute(_getBlockingInIsolate, {
    'libraryPath': _getLibraryPath(),
    'storePtr': _store!.address,
    'key': key,
    'delayMs': delayMs,
  });
}
```

**Key concepts:**
- Each isolate needs to re-open the library (`DynamicLibrary.open()`)
- Pass pointer addresses (integers) between isolates
- Return results via `SendPort`/`ReceivePort`

<!-- end_slide -->

# 7.2 Solution 2: Parallel Execution

**Multiple blocking calls can run in parallel**

```java
// Run 3 operations in parallel
final futures = [
  store.getBlockingAsync('name', delayMs: 500),
  store.getBlockingAsync('role', delayMs: 500),
  store.getBlockingAsync('project', delayMs: 500),
];

final results = await Future.wait(futures);
// Total time: ~500ms (not 1500ms!)
```

**Benefits:**
- Maximize throughput for I/O-bound operations
- UI stays responsive
- Natural Dart async/await patterns

<!-- end_slide -->

# 7.3 Solution 3: Streams

**Process results as they arrive**

```java
Stream<MapEntry<String, String?>> getBlockingStream(
  List<String> keys,
  {int delayMs = 1000}
) async* {
  for (final key in keys) {
    final value = await getBlockingAsync(key, delayMs: delayMs);
    yield MapEntry(key, value);
  }
}

// Use it
await for (final entry in store.getBlockingStream(keys)) {
  print('${entry.key} => ${entry.value}');
  // Update UI progressively!
}
```

<!-- end_slide -->

# 7.4 Demo: Blocking I/O

```bash
$ just run-blocking

--- Demo 1: Synchronous (blocks main thread) ---
⚠️  Warning: This will block for 500ms...
Result: Alyssa (took 500ms)

--- Demo 2: Async (runs in background isolate) ---
✓ Running in background isolate (non-blocking)...
Result: Engineer (took 500ms)

--- Demo 3: Multiple parallel async operations ---
✓ Running in background isolate (non-blocking)...
Results: [Alyssa, Engineer, Dart FFI]
Total time: 500ms (parallel execution!)

--- Demo 4: Stream-based processing ---
  Received: name => Alyssa
  Received: role => Engineer
  Received: project => Dart FFI
```

<!-- end_slide -->

# 7.5 Key Takeaways: Async FFI

**Problem:**
- Synchronous FFI blocks Dart's event loop
- UI freezes, no async work can happen

**Solutions:**
1. **Isolates** - Offload blocking work to background threads
2. **Future.wait()** - Parallel execution for multiple operations
3. **Streams** - Progressive results for better UX

**Implementation notes:**
- Each isolate must re-open the library
- Share pointer addresses (not pointers themselves)
- Use `compute()` helper or manual `Isolate.spawn()`
- Memory management still applies (free what you allocate!)

<!-- end_slide -->
# Questions?

**Project Structure:**
```
├── src/
│   └── kv_store.dart     # Dart FFI bindings + wrapper + tests + REPL
├── deps/kv/
│   ├── include/store.h   # C header
│   ├── src/store.c       # C implementation (modified)
│   └── lib/libkv.dylib   # Compiled shared library
└── README.md
```

**Running the code:**
```bash
just install       # Install Dart dependencies
just build         # Build C library
just run           # Run automated tests
just repl          # Interactive REPL mode
just run-blocking  # Blocking I/O demo (isolates/async)
just present       # View this presentation
```

Thank you!
