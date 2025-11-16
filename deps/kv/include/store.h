#ifndef STORE_H
#define STORE_H

#include <stddef.h>
#include <stdbool.h>

#ifdef _cplusplus
extern "C" {
#endif

typedef struct store store_t;

typedef enum {
    STORE_OK = 0,
    STORE_ERR_NOMEM = -1,
    STORE_ERR_NOTFOUND = -2,
    STORE_ERR_INVALID = -3,
    STORE_ERR_EXISTS = -4
} store_error_t;

/**
 * Create a new key-value store
 *
 * @return Pointer to new store, or NULL on error
 */
store_t* store_create(void);

/**
 * Destroy a key-value store and free all resources
 * 
 * @param store Store to destroy (may be NULL)
 */
void store_destroy(store_t* store);

/**
 * Put a key-value pair (replaces existing value if key exists)
 * 
 * @param store The key-value store
 * @param key Null-terminated key string
 * @param value Pointer to value data
 * @param value_size Size of value in bytes
 * @return STORE_OK on success, error code otherwise
 */
int store_put(store_t* store, const char* key, 
                const void* value, size_t value_size);

/**
 * Get a value by key
 * 
 * @param store The key-value store
 * @param key Null-terminated key string
 * @param value_out Pointer to receive value pointer (not copied)
 * @param value_size_out Pointer to receive value size
 * @return STORE_OK on success, STORE_ERR_NOTFOUND if key doesn't exist
 */
int store_get(store_t* store, const char* key,
                const void** value_out, size_t* value_size_out);

/**
 * Delete a key-value pair
 * 
 * @param store The key-value store
 * @param key Null-terminated key string
 * @return STORE_OK on success, STORE_ERR_NOTFOUND if key doesn't exist
 */
int store_delete(store_t* store, const char* key);

/**
 * Check if a key exists
 * 
 * @param store The key-value store
 * @param key Null-terminated key string
 * @return true if key exists, false otherwise
 */
bool store_exists(store_t* store, const char* key);

/**
 * Get the number of key-value pairs in the store
 * 
 * @param store The key-value store
 * @return Number of entries
 */
size_t store_size(store_t* store);

/**
 * Remove all entries from the store
 * 
 * @param store The key-value store
 */
void store_clear(store_t* store);

#ifdef __cplusplus
}
#endif

#endif
