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
3. Dart wrapper

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

# 3. Dart Wrapper

## constructor

### null Safety check

<!-- end_slide -->

# 3.2 Put

<!-- end_slide -->

# 3.3 Get

<!-- end_slide -->

# 3.4 Delete

<!-- end_slide -->

# 3.5 Exists

<!-- end_slide -->

# 3.6 get size

<!-- end_slide -->

# 3.7 Clear
