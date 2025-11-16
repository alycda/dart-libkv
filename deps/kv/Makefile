# Compiler and flags
CC = gcc
CFLAGS = -Wall -Wextra -Werror -std=c11 -pedantic -D_POSIX_C_SOURCE=200809L
LDFLAGS =
INCLUDES = -Iinclude

# AddressSanitizer support (use: make tests ASAN=1)
ifdef ASAN
    ASAN_FLAGS = -fsanitize=address -fno-omit-frame-pointer -g
    CFLAGS += $(ASAN_FLAGS)
    LDFLAGS += $(ASAN_FLAGS)
endif

# Directories
SRC_DIR = src
INC_DIR = include
BUILD_DIR = build
LIB_DIR = lib
TEST_DIR = tests
EXAMPLE_DIR = examples
DOCS_DIR = docs

# Library
LIB_NAME = libkv.a
LIB = $(LIB_DIR)/$(LIB_NAME)

# Source files
SOURCES = $(wildcard $(SRC_DIR)/*.c)
OBJECTS = $(SOURCES:$(SRC_DIR)/%.c=$(BUILD_DIR)/%.o)

# Test files
TEST_SOURCES = $(wildcard $(TEST_DIR)/*.c)
TEST_OBJECTS = $(TEST_SOURCES:$(TEST_DIR)/%.c=$(BUILD_DIR)/%.o)
TEST_BINS = $(TEST_SOURCES:$(TEST_DIR)/%.c=$(BUILD_DIR)/%)

# Example files
EXAMPLE_SOURCES = $(wildcard $(EXAMPLE_DIR)/*.c)
EXAMPLE_BINS = $(EXAMPLE_SOURCES:$(EXAMPLE_DIR)/%.c=$(BUILD_DIR)/%)

# Default target
all: $(LIB)

# Create directories
$(BUILD_DIR) $(LIB_DIR):
	mkdir -p $@

# Build library
$(LIB): $(OBJECTS) | $(LIB_DIR)
	ar rcs $@ $^

# Compile source files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Compile test files
$(BUILD_DIR)/%.o: $(TEST_DIR)/%.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Build tests
tests: $(LIB) $(TEST_BINS)

$(BUILD_DIR)/test_%: $(BUILD_DIR)/test_%.o $(LIB)
	$(CC) $(CFLAGS) $< $(LIB) -o $@ $(LDFLAGS)

# Build examples
examples: $(LIB) $(EXAMPLE_BINS)

$(BUILD_DIR)/%: $(EXAMPLE_DIR)/%.c $(LIB)
	$(CC) $(CFLAGS) $(INCLUDES) $< $(LIB) -o $@ $(LDFLAGS)

# Run tests
check: tests
	@for test in $(TEST_BINS); do \
		echo "Running $$test..."; \
		./$$test || exit 1; \
	done

# Generate documentation
docs:
	doxygen Doxyfile
	@echo "Documentation generated in $(DOCS_DIR)/html/index.html"

# Clean
clean:
	rm -rf $(BUILD_DIR) $(LIB_DIR) $(DOCS_DIR)

# Install (optional)
install: $(LIB)
	install -d /usr/local/lib
	install -m 644 $(LIB) /usr/local/lib/
	install -d /usr/local/include/store
	install -m 644 $(INC_DIR)/*.h /usr/local/include/store/

# Uninstall (optional)
uninstall:
	rm -f /usr/local/lib/$(LIB_NAME)
	rm -rf /usr/local/include/store

.PHONY: all tests examples check docs clean install uninstall
