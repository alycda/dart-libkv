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

<!-- end_slide -->

# 1. Building a Dynamic Library

**Three key changes to the Makefile:**

1. Add `-fPIC` (Position Independent Code) to CFLAGS
2. Change library name from `.a` to `.dylib`
3. Use `-shared` flag when linking

```file +line_numbers
path: deps/kv/Makefile
language: makefile
start_line: 3
end_line: 3
```

```file +line_numbers
path: deps/kv/Makefile
language: makefile
start_line: 24
end_line: 25
```

```file +line_numbers
path: deps/kv/Makefile
language: makefile
start_line: 48
end_line: 49
```

**Why?** Dart FFI requires dynamic libraries, not static archives.

<!-- end_slide -->

# 1.1 Loading the Library: Cross-Platform Paths

**Challenge:** Need to load the library on both macOS and Linux

```file +line_numbers
path: src/kv_store.dart
language: dart
start_line: 6
end_line: 16
```

**Key decisions:**
- Use **absolute paths** (relative paths fail in Nix/hardened environments)
- Detect platform at **runtime** (`Platform.isMacOS`)
- Match Makefile platform detection for `.dylib` vs `.so`

<!-- end_slide -->

# 2. FFI Foundations: Opaque Types

**Problem:** C library uses `store_t*` (opaque pointer to internal struct)

**Solution:** Dart's `Opaque` type

```file +line_numbers
path: src/kv_store.dart
language: dart
start_line: 18
end_line: 18
```

**Why Opaque?**
- We don't need to know the internal structure
- C library owns the memory
- We just pass the pointer around

<!-- end_slide -->

# 2.1 Error Handling Strategy

**C library returns error codes** (int: 0 = success, negative = error)

```file +line_numbers
path: src/kv_store.dart
language: dart
start_line: 20
end_line: 37
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
┌─────────────────────────────────────────────────┐
│ Dart Application Layer                          │
│  store.put("name", "Alyssa")                    │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│ Dart FFI Binding Layer                          │
│  - Convert Dart String → Pointer<Utf8>          │
│  - Allocate memory (malloc)                     │
│  - Call C function                              │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│ C Library (libkv.dylib)                         │
│  - store_put(store, key, value, size)           │
│  - Allocate & copy data in C heap               │
└─────────────────────────────────────────────────┘
```

<!-- end_slide -->

# 2.4 Data Flow: C → Dart

```
┌─────────────────────────────────────────────────┐
│ C Library Returns                               │
│  - Pointer to C-owned memory                    │
│  - Size of data                                 │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│ Dart FFI Binding Layer                          │
│  - asTypedList() to view C memory               │
│  - String.fromCharCodes() to copy data          │
│  - Free allocated Dart pointers (NOT C data!)   │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│ Dart Application                                │
│  String? value = store.get("name")              │
└─────────────────────────────────────────────────┘
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

**The Dart Side:**
```dart
void put(String key, String value) {
  final keyPtr = key.toNativeUtf8();     // Allocate
  final valuePtr = value.toNativeUtf8(); // Allocate

  try {
    _storePut(_store!, keyPtr, valuePtr.cast(),
              valuePtr.length);
  } finally {
    malloc.free(keyPtr);      // ALWAYS free
    malloc.free(valuePtr);    // Even on exception!
  }
}
```

**The C Side:**
```c
int store_get(store_t* store, const char* key,
              const void** value_out, size_t* value_size_out) {
    *value_out = store->entries[i].value;  // ← C owns this!
    *value_size_out = store->entries[i].value_size;
    return STORE_OK;
}
```

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

```file +line_numbers
path: src/kv_store.dart
language: dart
start_line: 108
end_line: 117
```

```file +line_numbers
path: src/kv_store.dart
language: dart
start_line: 215
end_line: 220
```

```file +line_numbers
path: src/kv_store.dart
language: dart
start_line: 207
end_line: 213
```

**Lifecycle management:**
- Constructor throws if creation fails
- `_checkStore()` prevents use-after-dispose
- `dispose()` cleans up and nullifies pointer

<!-- end_slide -->

# 3.2 Writing Data: put()

```file +line_numbers
path: src/kv_store.dart
language: dart
start_line: 119
end_line: 135
```

**Key patterns:**
- `toNativeUtf8()` allocates → **must free**
- `try/finally` ensures cleanup even on exception
- Error codes converted to exceptions with helpful messages

<!-- end_slide -->

# 3.3 Reading Data: get()

```file +line_numbers
path: src/kv_store.dart
language: dart
start_line: 137
end_line: 167
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

```dart
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
```
