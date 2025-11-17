# Default recipe - build and run
# note that the FIRST recipe is ALWAYS the default, the recipe name DOES NOT MATTER
default: build run

# Install Dart dependencies
install:
    dart pub get

# Check C and Dart code
check: test
    dart analyze

# Run the Dart application (assumes C library is built)
run:
    dart src/kv_store.dart

# Run the interactive REPL
repl:
    dart src/kv_store.dart --repl

# Run the blocking I/O demonstration
run-blocking:
    dart src/kv_store.dart --blocking

present:
    presenterm presentation.md

# Run C and Dart tests
test: test-c
    dart src/kv_store.dart --test

# Run C tests
[working-directory: 'deps/kv']
test-c: clean
    make check

# Clean C artifacts only (default clean)
[working-directory: 'deps/kv']
clean:
    make clean

# Clean C and Dart artifacts
clean-all: clean
    rm -rf .dart_tool .packages pubspec.lock

# Clean and reinstall Dart dependencies
clean-get: clean-all install

# Clean and rebuild C library
[working-directory: 'deps/kv']
build: clean
    make
