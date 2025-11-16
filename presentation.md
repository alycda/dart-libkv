---
title: Dart FFI with libkv
sub_title: Building Safe C Bindings in Dart
author: Alyssa Evans
---

# Overview

Building Dart FFI bindings for a C key-value store library

## Steps

1. build dylib instead of static c lib

<!-- end_slide -->

# Building a Dynamic Library

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