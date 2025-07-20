#ifdef __cplusplus
extern "C" {
#endif

#include "allocator.h"

#include "utils/assert.h"
#include <stdlib.h>
#include <stdbool.h>

//https://microsoft.github.io/mimalloc/overrides.html
/*
// C
void*  malloc(size_t size);
void*  calloc(size_t size, size_t n);
void*  realloc(void* p, size_t newsize);
void   free(void* p);
 
void*  aligned_alloc(size_t alignment, size_t size);
char*  strdup(const char* s);
char*  strndup(const char* s, size_t n);
char*  realpath(const char* fname, char* resolved_name);
 
 
// C++
void   operator delete(void* p);
void   operator delete[](void* p);
 
void*  operator new(std::size_t n) noexcept(false);
void*  operator new[](std::size_t n) noexcept(false);
void*  operator new( std::size_t n, std::align_val_t align) noexcept(false);
void*  operator new[]( std::size_t n, std::align_val_t align) noexcept(false);
 
void*  operator new  ( std::size_t count, const std::nothrow_t& tag);
void*  operator new[]( std::size_t count, const std::nothrow_t& tag);
void*  operator new  ( std::size_t count, std::align_val_t al, const std::nothrow_t&);
void*  operator new[]( std::size_t count, std::align_val_t al, const std::nothrow_t&);
*/

static bool heap_locked = false;
void lock_heap() { heap_locked = true; }

void *__real_malloc(size_t size);

void *__wrap_malloc(size_t size) {
    if(heap_locked){
        log_error("[__wrap_malloc] someone is trying to use the heap after is was locked!");
        ASSERT(false);
    };
    void *ptr = __real_malloc(size);
    return ptr;
}

void *__real_cmalloc(size_t size, size_t n);

void *__wrap_cmalloc(size_t size, size_t n) {
    if(heap_locked){
        log_error("[__wrap_cmalloc] someone is trying to use the heap after is was locked!");
        ASSERT(false);
    };
    void *ptr = __real_cmalloc(size, n);
    return ptr;
}

void *__real_realloc(void* p, size_t newsize);

void *__wrap_realloc(void* p, size_t newsize) {
    if(heap_locked){
        log_error("[__wrap_realloc] someone is trying to use the heap after is was locked!");
        ASSERT(false);
    };
    void *ptr = __real_realloc(p, newsize);
    return ptr;
}

void __real_free(void* p);

void __wrap_free(void* p) {
    if(heap_locked){
        log_error("[__wrap_free] someone is trying to use the heap after is was locked!");
        ASSERT(false);
    };
    __real_free(p);
}

#ifdef __cplusplus
}
#endif
