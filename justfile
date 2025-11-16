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

present:
    presenterm presentation.md

# Run C tests
[working-directory: 'deps/kv']
test: clean
    make check
    
# Clean C artifacts
[working-directory: 'deps/kv']
clean:
    make clean

# Clean and rebuild C library
[working-directory: 'deps/kv']
build: clean
    make