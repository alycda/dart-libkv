#include "../include/store.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>

#define TEST(name) \
    do { \
        printf("Running test: %s...", #name); \
        fflush(stdout); \
        test_##name(); \
        printf(" PASSED\n"); \
    } while(0)

/* Helper function to compare byte arrays */
static int compare_bytes(const void* a, const void* b, size_t size) {
    return memcmp(a, b, size);
}

void test_create_destroy(void) {
    store_t* store = store_create();
    assert(store != NULL);
    assert(store_size(store) == 0);
    store_destroy(store);
    
    /* Destroying NULL should not crash */
    store_destroy(NULL);
}

void test_put_get_string(void) {
    store_t* store = store_create();
    assert(store != NULL);
    printf("\n  Store created, size=%zu\n", store_size(store));
    
    const char* value = "hello world";
    printf("  Calling store_put: store=%p, key=%s, value=%p ('%s'), size=%zu\n",
           (void*)store, "key1", (const void*)value, value, strlen(value) + 1);
    int result = store_put(store, "key1", value, strlen(value) + 1);
    printf("  Put result: %d, size=%zu\n", result, store_size(store));
    assert(result == STORE_OK);
    assert(store_size(store) == 1);
    
    printf("  About to get...\n");
    const void* retrieved;
    size_t size;
    result = store_get(store, "key1", &retrieved, &size);
    printf("  Get result: %d\n", result);
    assert(result == STORE_OK);
    assert(size == strlen(value) + 1);
    assert(strcmp((const char*)retrieved, value) == 0);
    
    store_destroy(store);
}

void test_put_get_integers(void) {
    store_t* store = store_create();
    assert(store != NULL);
    
    int value1 = 42;
    int value2 = 123;
    
    assert(store_put(store, "int1", &value1, sizeof(int)) == STORE_OK);
    assert(store_put(store, "int2", &value2, sizeof(int)) == STORE_OK);
    assert(store_size(store) == 2);
    
    const void* retrieved;
    size_t size;
    
    assert(store_get(store, "int1", &retrieved, &size) == STORE_OK);
    assert(size == sizeof(int));
    assert(*(const int*)retrieved == 42);
    
    assert(store_get(store, "int2", &retrieved, &size) == STORE_OK);
    assert(size == sizeof(int));
    assert(*(const int*)retrieved == 123);
    
    store_destroy(store);
}

void test_put_replace(void) {
    store_t* store = store_create();
    assert(store != NULL);
    
    const char* value1 = "first";
    const char* value2 = "second value is longer";
    
    assert(store_put(store, "key", value1, strlen(value1) + 1) == STORE_OK);
    assert(store_size(store) == 1);
    
    /* Replace with different sized value */
    assert(store_put(store, "key", value2, strlen(value2) + 1) == STORE_OK);
    assert(store_size(store) == 1);
    
    const void* retrieved;
    size_t size;
    assert(store_get(store, "key", &retrieved, &size) == STORE_OK);
    assert(strcmp((const char*)retrieved, value2) == 0);
    
    store_destroy(store);
}

void test_get_notfound(void) {
    store_t* store = store_create();
    assert(store != NULL);
    
    const void* retrieved;
    size_t size;
    int result = store_get(store, "nonexistent", &retrieved, &size);
    assert(result == STORE_ERR_NOTFOUND);
    
    store_destroy(store);
}

void test_exists(void) {
    store_t* store = store_create();
    assert(store != NULL);
    
    assert(store_exists(store, "key1") == false);
    
    const char* value = "test";
    store_put(store, "key1", value, strlen(value) + 1);
    
    assert(store_exists(store, "key1") == true);
    assert(store_exists(store, "key2") == false);
    
    store_destroy(store);
}

void test_delete(void) {
    store_t* store = store_create();
    assert(store != NULL);
    
    const char* value = "test";
    store_put(store, "key1", value, strlen(value) + 1);
    store_put(store, "key2", value, strlen(value) + 1);
    assert(store_size(store) == 2);
    
    assert(store_delete(store, "key1") == STORE_OK);
    assert(store_size(store) == 1);
    assert(store_exists(store, "key1") == false);
    assert(store_exists(store, "key2") == true);
    
    assert(store_delete(store, "nonexistent") == STORE_ERR_NOTFOUND);
    
    store_destroy(store);
}

void test_clear(void) {
    store_t* store = store_create();
    assert(store != NULL);
    
    const char* value = "test";
    store_put(store, "key1", value, strlen(value) + 1);
    store_put(store, "key2", value, strlen(value) + 1);
    store_put(store, "key3", value, strlen(value) + 1);
    assert(store_size(store) == 3);
    
    store_clear(store);
    assert(store_size(store) == 0);
    assert(store_exists(store, "key1") == false);
    assert(store_exists(store, "key2") == false);
    assert(store_exists(store, "key3") == false);
    
    /* Can still use store after clear */
    store_put(store, "new_key", value, strlen(value) + 1);
    assert(store_size(store) == 1);
    
    store_destroy(store);
}

void test_multiple_entries(void) {
    store_t* store = store_create();
    assert(store != NULL);
    
    /* Add many entries */
    for (int i = 0; i < 100; i++) {
        char key[32];
        snprintf(key, sizeof(key), "key%d", i);
        assert(store_put(store, key, &i, sizeof(int)) == STORE_OK);
    }
    
    assert(store_size(store) == 100);
    
    /* Verify all entries */
    for (int i = 0; i < 100; i++) {
        char key[32];
        snprintf(key, sizeof(key), "key%d", i);
        
        const void* retrieved;
        size_t size;
        assert(store_get(store, key, &retrieved, &size) == STORE_OK);
        assert(*(const int*)retrieved == i);
    }
    
    store_destroy(store);
}

void test_binary_data(void) {
    store_t* store = store_create();
    assert(store != NULL);
    
    unsigned char data[] = {0x00, 0x01, 0x02, 0xFF, 0xFE, 0x00, 0x42};
    size_t data_size = sizeof(data);
    
    assert(store_put(store, "binary", data, data_size) == STORE_OK);
    
    const void* retrieved;
    size_t size;
    assert(store_get(store, "binary", &retrieved, &size) == STORE_OK);
    assert(size == data_size);
    assert(compare_bytes(retrieved, data, data_size) == 0);
    
    store_destroy(store);
}

void test_empty_key(void) {
    store_t* store = store_create();
    assert(store != NULL);
    
    const char* value = "test";
    assert(store_put(store, "", value, strlen(value) + 1) == STORE_OK);
    
    const void* retrieved;
    size_t size;
    assert(store_get(store, "", &retrieved, &size) == STORE_OK);
    assert(strcmp((const char*)retrieved, value) == 0);
    
    store_destroy(store);
}

void test_null_parameters(void) {
    store_t* store = store_create();
    assert(store != NULL);
    
    const char* value = "test";
    const void* retrieved;
    size_t size;
    
    /* NULL store */
    assert(store_put(NULL, "key", value, 4) == STORE_ERR_INVALID);
    assert(store_get(NULL, "key", &retrieved, &size) == STORE_ERR_INVALID);
    assert(store_delete(NULL, "key") == STORE_ERR_INVALID);
    assert(store_exists(NULL, "key") == false);
    assert(store_size(NULL) == 0);
    
    /* NULL key */
    assert(store_put(store, NULL, value, 4) == STORE_ERR_INVALID);
    assert(store_get(store, NULL, &retrieved, &size) == STORE_ERR_INVALID);
    assert(store_delete(store, NULL) == STORE_ERR_INVALID);
    assert(store_exists(store, NULL) == false);
    
    /* NULL value */
    assert(store_put(store, "key", NULL, 4) == STORE_ERR_INVALID);
    
    /* NULL output parameters */
    assert(store_get(store, "key", NULL, &size) == STORE_ERR_INVALID);
    assert(store_get(store, "key", &retrieved, NULL) == STORE_ERR_INVALID);
    
    store_destroy(store);
}

void test_long_keys(void) {
    store_t* store = store_create();
    assert(store != NULL);
    
    char long_key[1000];
    memset(long_key, 'a', sizeof(long_key) - 1);
    long_key[sizeof(long_key) - 1] = '\0';
    
    const char* value = "test";
    assert(store_put(store, long_key, value, strlen(value) + 1) == STORE_OK);
    
    const void* retrieved;
    size_t size;
    assert(store_get(store, long_key, &retrieved, &size) == STORE_OK);
    assert(strcmp((const char*)retrieved, value) == 0);
    
    store_destroy(store);
}

int main(void) {
    printf("Running store tests...\n\n");
    
    TEST(create_destroy);
    TEST(put_get_string);
    TEST(put_get_integers);
    TEST(put_replace);
    TEST(get_notfound);
    TEST(exists);
    TEST(delete);
    TEST(clear);
    TEST(multiple_entries);
    TEST(binary_data);
    TEST(empty_key);
    TEST(null_parameters);
    TEST(long_keys);
    
    printf("\nAll tests passed!\n");
    return 0;
}
