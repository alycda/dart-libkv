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
build-libkv: clean
    make