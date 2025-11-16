#include "store.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdbool.h>

typedef struct entry {
    char* key;
    void* value;
    size_t value_size;
} entry_t;

/* Store structure */
struct store {
    entry_t* entries;
    size_t size;
    size_t capacity;
};

store_t* store_create(void) {
    store_t* store = malloc(sizeof(store_t));
    if (!store) {
        return NULL;
    }
    store->entries = NULL;
    store->size = 0;
    store->capacity = 0;
    return store;
}

void store_destroy(store_t* store) {
    if (!store) {
        return;
    }
    for (size_t i = 0; i < store->size; i++) {
        free(store->entries[i].key);
        free(store->entries[i].value);
    }
    free(store->entries);
    free(store);
}

int store_put(store_t* store, const char* key, const void* value, size_t value_size) {
    if (!store || !key || !value) {
        return STORE_ERR_INVALID;
    }
    
    /* Check if key already exists */
    for (size_t i = 0; i < store->size; i++) {
        if (strcmp(store->entries[i].key, key) == 0) {
            /* Replace existing value */
            void* new_value = malloc(value_size);
            if (!new_value) {
                return STORE_ERR_NOMEM;
            }
            memcpy(new_value, value, value_size);
            free(store->entries[i].value);
            store->entries[i].value = new_value;
            store->entries[i].value_size = value_size;
            return STORE_OK;
        }
    }
    
    /* Key doesn't exist - check if we need to grow */
    if (store->size >= store->capacity) {
        /* Determine new capacity - start with 4, then double */
        size_t new_capacity = store->capacity == 0 ? 4 : store->capacity * 2;
        
        /* Reallocate array */
        entry_t* new_entries = realloc(store->entries, new_capacity * sizeof(entry_t));
        if (!new_entries) {
            return STORE_ERR_NOMEM;
        }
        
        store->entries = new_entries;
        store->capacity = new_capacity;
    }
    
    /* Initialize the new entry */
    entry_t* entry = &store->entries[store->size];
    
    entry->key = strdup(key);
    if (!entry->key) {
        return STORE_ERR_NOMEM;
    }
    
    entry->value = malloc(value_size);
    if (!entry->value) {
        free(entry->key);
        return STORE_ERR_NOMEM;
    }
    
    memcpy(entry->value, value, value_size);
    entry->value_size = value_size;
    store->size++;
    
    return STORE_OK;
}

int store_get(store_t* store, const char* key, const void** value_out, size_t* value_size_out) {
    if (!store || !key || !value_out || !value_size_out) {
        return STORE_ERR_INVALID;
    }
    
    for (size_t i = 0; i < store->size; i++) {
        if (strcmp(store->entries[i].key, key) == 0) {
            *value_out = store->entries[i].value;
            *value_size_out = store->entries[i].value_size;
            return STORE_OK;
        }
    }
    
    return STORE_ERR_NOTFOUND;
}

int store_delete(store_t* store, const char* key) {
    if (!store || !key) {
        return STORE_ERR_INVALID;
    }
    
    for (size_t i = 0; i < store->size; i++) {
        if (strcmp(store->entries[i].key, key) == 0) {
            free(store->entries[i].key);
            free(store->entries[i].value);
            
            /* Move last entry to deleted position */
            if (i < store->size - 1) {
                store->entries[i] = store->entries[store->size - 1];
            }
            
            store->size--;
            
            /* Optional: shrink capacity if we're using less than 1/4 of it */
            /* This prevents wasting too much memory after many deletions */
            if (store->capacity > 4 && store->size < store->capacity / 4) {
                size_t new_capacity = store->capacity / 2;
                entry_t* new_entries = realloc(store->entries, new_capacity * sizeof(entry_t));
                if (new_entries) {  /* Only shrink if realloc succeeds */
                    store->entries = new_entries;
                    store->capacity = new_capacity;
                }
            }
            
            return STORE_OK;
        }
    }
    
    return STORE_ERR_NOTFOUND;
}

size_t store_size(store_t* store) {
    if (!store) {
        return 0;
    }
    return store->size;
}

void store_clear(store_t* store) {
    if (!store) {
        return;
    }
    
    for (size_t i = 0; i < store->size; i++) {
        free(store->entries[i].key);
        free(store->entries[i].value);
    }
    
    store->size = 0;
    /* Keep the capacity allocated for potential reuse */
}

bool store_exists(store_t* store, const char* key) {
    if (!store || !key) {
        return false;
    }
    
    for (size_t i = 0; i < store->size; i++) {
        if (strcmp(store->entries[i].key, key) == 0) {
            return true;
        }
    }
    
    return false;
}
