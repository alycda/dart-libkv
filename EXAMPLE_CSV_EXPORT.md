# CSV Export Example

## Using the REPL

```bash
$ just repl

kv> put name Alyssa
✓ Stored: "name" => "Alyssa"

kv> put age 30
✓ Stored: "age" => "30"

kv> put city San Francisco
✓ Stored: "city" => "San Francisco"

kv> put bio "Software Engineer, loves Rust"
✓ Stored: "bio" => "Software Engineer, loves Rust"

kv> list
Keys (4):
  - name
  - age
  - city
  - bio

kv> export
key,value
name,Alyssa
age,30
city,San Francisco
bio,"Software Engineer, loves Rust"

kv> export data.csv
✓ Exported to "data.csv"

kv> exit
Goodbye!
```

## Programmatic Usage

```dart
import 'dart:io';
import 'kv_store.dart';

void main() {
  final store = KeyValueStore();

  // Add some data
  store.put('user:1:name', 'Alice Smith');
  store.put('user:1:email', 'alice@example.com');
  store.put('user:2:name', 'Bob Jones');
  store.put('user:2:email', 'bob@example.com');

  // Get all keys
  final keys = store.getAllKeys();
  print('Total keys: ${keys.length}');

  // Export to CSV string
  final csvString = store.exportToCsv();
  print(csvString);

  // Export to file
  store.exportToCsvFile('users.csv');
  print('Exported to users.csv');

  // Clean up
  store.dispose();
}
```

## CSV Format

The CSV export follows standard CSV conventions:

- **Header row**: `key,value`
- **Quoted fields**: Fields containing commas, quotes, or newlines are automatically quoted
- **Escaped quotes**: Double quotes within fields are escaped as `""`

### Example with special characters:

```csv
key,value
name,Alyssa
description,"Software Engineer, loves Rust"
quote,"She said ""Hello!"""
multiline,"Line 1
Line 2"
```

## Implementation Details

### C Library Addition

Added `store_get_key_at()` function to enable iteration:

```c
int store_get_key_at(store_t* store, size_t index, const char** key_out);
```

This allows efficient iteration through all keys without exposing internal data structures.

### Dart Methods

Three new methods in `KeyValueStore`:

1. **`getAllKeys()`** - Returns `List<String>` of all keys
2. **`exportToCsv()`** - Returns CSV-formatted `String`
3. **`exportToCsvFile(String path)`** - Writes CSV to file

### CSV Field Escaping

The `_escapeCsvField()` helper handles:
- Commas in values (wraps in quotes)
- Double quotes (escapes as `""`)
- Newlines (preserves in quoted fields)
