/*
 * This test is intended to be run under memory debugger such as Valgrind or Dr.Memory.
 * Normally it should complete without errors and should exhibit no memory-related issues.
 * The test should be compilable with any ANSI C compiler.
 * 
 * > cc test.c test_auto.c
*/


#include <assert.h>
#include <memory.h>
#include <stdio.h>


#include "test.h"
#include "test_auto.h"


#define SIZE 16
void ValueTypeCtorEx(ValueType* self, int value) {
    assert(self);
    self->value = value;
    self->block = malloc(SIZE); assert(self->block);
}


void ValueTypeCtorRef(ValueType* self) {
    ValueTypeCtorEx(self, 0);
}


void ValueTypeDtorRef(ValueType* self) {
    assert(self);
    free(self->block);
}


void ValueTypeCopyRef(ValueType* dst, ValueType* src) {
    assert(src);
    assert(dst);
    dst->block = malloc(SIZE); assert(dst->block);
    dst->value = src->value;
    memcpy(dst->block, src->block, SIZE);
}


int ValueTypeEqualRef(ValueType* lt, ValueType* rt) {
    assert(lt);
    assert(rt);
    return lt->value == rt->value;
}


int ValueTypeLessRef(ValueType* lt, ValueType* rt) {
    assert(lt);
    assert(rt);
    return lt->value < rt->value;
}


size_t ValueTypeIdentifyRef(ValueType* self) {
    assert(self);
    return (size_t)self->value;
}


#undef element
#define element(x) ValueType##x


#undef Type
#define Type ValueTypeVector
#undef TypeIt
#define TypeIt ValueTypeVectorIt
#undef type
#define type(x) ValueTypeVector##x
#undef it
#define it(x) ValueTypeVectorIt##x


void type(Test)() {
    ValueType e1, e2;
    Type c1, c2;
    TypeIt it;
    
    type(Ctor)(&c1, 3);
    type(Copy)(&c2, &c1);
    
    type(Resize)(&c1, 5);
    type(Size)(&c1);
    type(Equal)(&c1, &c2);
    type(Resize)(&c1, 3);
    type(Size)(&c1);
    type(Equal)(&c1, &c2);
    
    type(Within)(&c1, 0);
    type(Within)(&c1, 10);
    
    element(CtorEx)(&e1, -1);
    element(CtorEx)(&e2, +1);
    type(Set)(&c1, 2, e1);
    type(Set)(&c1, 0, e2);
    element(Dtor)(e1);
    element(Dtor)(e2);
    
    it(Ctor)(&it, &c1);
    while(it(Move)(&it)) {
        ValueType e = it(Get)(&it);
        element(Dtor)(e);
    }
    
    it(CtorEx)(&it, &c2, 0);
    while(it(Move)(&it)) {
        ValueType e = it(Get)(&it);
        element(Dtor)(e);
    }

    type(Sort)(&c1);
    type(Sort)(&c2);
    
    type(Identify)(&c1);
    type(Identify)(&c2);
    
    type(Dtor)(&c1);
    type(Dtor)(&c2);
}


#undef Type
#define Type ValueTypeList
#undef TypeIt
#define TypeIt ValueTypeListIt
#undef type
#define type(x) ValueTypeList##x
#undef it
#define it(x) ValueTypeListIt##x


void type(Test)() {
    ValueType e1, e2, e3;
    Type c1, c2;
    TypeIt it;
    
    type(Ctor)(&c1);
    type(Copy)(&c2, &c1);
    
    type(Equal)(&c1, &c2);
    type(Empty)(&c1);
    
    it(Ctor)(&it, &c1);
    while(it(Move)(&it)) {
        ValueType e = it(Get)(&it);
        element(Dtor)(e);
    }
    
    element(CtorEx)(&e1, -1);
    element(CtorEx)(&e2, +1);
    
    type(Push)(&c1, e1);
    type(Push)(&c2, e2);
    type(Contains)(&c1, e1);
    type(Contains)(&c2, e1);
    type(Push)(&c1, e2);
    type(Push)(&c2, e1);
    type(Empty)(&c1);
    
    element(Dtor)(e1);
    element(Dtor)(e2);

    e1 = type(Peek)(&c1);
    e2 = type(Peek)(&c2);
    element(Dtor)(e1);
    element(Dtor)(e2);
    
    it(Ctor)(&it, &c1);
    while(it(Move)(&it)) {
        ValueType e = it(Get)(&it);
        element(Dtor)(e);
    }

    type(Identify)(&c1);
    type(Identify)(&c2);

    e1 = type(Pop)(&c1);
    e2 = type(Pop)(&c2);
    element(Dtor)(e1);
    element(Dtor)(e2);

    type(Purge)(&c1);
    type(Purge)(&c2);

    element(CtorEx)(&e1, 3);
    element(CtorEx)(&e2, -3);
    element(Copy)(e3, e2);
    type(Push)(&c1, e1);
    type(Push)(&c1, e2);
    type(Push)(&c1, e1);
    type(Push)(&c2, e2);
    type(Push)(&c2, e2);
    type(Push)(&c2, e2);
    type(Replace)(&c2, e3);
    type(ReplaceAll)(&c2, e3);
    type(Remove)(&c1, e2);
    type(Remove)(&c1, e1);
    type(Remove)(&c2, e1);
    type(RemoveAll)(&c2, e2);
    element(Dtor)(e1);
    element(Dtor)(e2);
    element(Dtor)(e3);

    type(Dtor)(&c1);
    type(Dtor)(&c2);
}


#undef Type
#define Type ValueTypeQueue
#undef TypeIt
#define TypeIt ValueTypeQueueIt
#undef type
#define type(x) ValueTypeQueue##x
#undef it
#define it(x) ValueTypeQueueIt##x


/*
 * Queue is a non-strict superset of List
 * so the test case for the latter can be reused as-is 
 */
void type(Test)() {
    ValueType e1, e2, e3;
    Type c1, c2;
    TypeIt it;
    
    type(Ctor)(&c1);
    type(Copy)(&c2, &c1);
    
    type(Equal)(&c1, &c2);
    type(Empty)(&c1);
    
    it(Ctor)(&it, &c1);
    while(it(Move)(&it)) {
        ValueType e = it(Get)(&it);
        element(Dtor)(e);
    }
    
    element(CtorEx)(&e1, -1);
    element(CtorEx)(&e2, +1);
    
    type(Push)(&c1, e1);
    type(Push)(&c2, e2);
    type(Contains)(&c1, e1);
    type(Contains)(&c2, e1);
    type(Push)(&c1, e2);
    type(Push)(&c2, e1);
    type(Empty)(&c1);
    
    element(Dtor)(e1);
    element(Dtor)(e2);

    e1 = type(Peek)(&c1);
    e2 = type(Peek)(&c2);
    element(Dtor)(e1);
    element(Dtor)(e2);
    
    it(Ctor)(&it, &c1);
    while(it(Move)(&it)) {
        ValueType e = it(Get)(&it);
        element(Dtor)(e);
    }

    type(Identify)(&c1);
    type(Identify)(&c2);

    e1 = type(Pop)(&c1);
    e2 = type(Pop)(&c2);
    element(Dtor)(e1);
    element(Dtor)(e2);

    type(Purge)(&c1);
    type(Purge)(&c2);

    element(CtorEx)(&e1, 3);
    element(CtorEx)(&e2, -3);
    element(Copy)(e3, e2);
    type(Push)(&c1, e1);
    type(Push)(&c1, e2);
    type(Push)(&c1, e1);
    type(Push)(&c2, e2);
    type(Push)(&c2, e2);
    type(Push)(&c2, e2);
    type(Replace)(&c2, e3);
    type(ReplaceAll)(&c2, e3);
    type(Remove)(&c1, e2);
    type(Remove)(&c1, e1);
    type(Remove)(&c2, e1);
    type(RemoveAll)(&c2, e2);
    element(Dtor)(e1);
    element(Dtor)(e2);
    element(Dtor)(e3);

    type(Dtor)(&c1);
    type(Dtor)(&c2);
}


#undef Type
#define Type ValueTypeSet
#undef TypeIt
#define TypeIt ValueTypeSetIt
#undef type
#define type(x) ValueTypeSet##x
#undef it
#define it(x) ValueTypeSetIt##x


void type(Test)() {
    ValueType e1, e2, e3;
    Type c1, c2;
    TypeIt it;
    
    type(Ctor)(&c1);
    type(Copy)(&c2, &c1);
    
    it(Ctor)(&it, &c1);
    while(it(Move)(&it)) {
        ValueType e = it(Get)(&it);
        element(Dtor)(e);
    }

    type(Equal)(&c1, &c2);
    type(Empty)(&c1);
    type(Size)(&c1);
    
    element(CtorEx)(&e1, -1);
    element(CtorEx)(&e2, +1);
    element(CtorEx)(&e3, 0);

    type(Put)(&c1, e1);
    type(Put)(&c2, e1);
    type(Equal)(&c1, &c2);
    type(Put)(&c1, e2);
    type(Put)(&c2, e3);
    type(Equal)(&c1, &c2);
    type(Contains)(&c1, e1);
    type(Contains)(&c2, e2);
    {
        ValueType e = type(Get)(&c2, e3);
        element(Dtor)(e);
    }
    type(Replace)(&c1, e2);
    type(Identify)(&c1);
    type(Identify)(&c2);

    element(Dtor)(e1);
    element(Dtor)(e2);
    element(Dtor)(e3);
    
    {
        int i;
        ValueType e;
        for(i = 0; i < 100; ++i) {
            element(CtorEx)(&e, i);
            type(Put)(&c1, e);
            element(Dtor)(e);
        }
        for(i = 0; i < 100; i += 2) {
            element(CtorEx)(&e, i);
            type(Remove)(&c1, e);
            element(Dtor)(e);
        }
        it(Ctor)(&it, &c1);
        while(it(Move)(&it)) {
            ValueType e = it(Get)(&it);
            element(Dtor)(e);
        }
    }
    
    type(Purge)(&c1);
    type(Dtor)(&c1);
    type(Dtor)(&c2);
}


#undef type
#define type(x) ValueTypeMap##x
void type(Test)() {
    int i;
    ValueType e1, e2, v3;
    ValueTypeMap c, c2;
    printf("\n*** HashMap<ValueType->ValueType>\n");
    element(CtorEx)(&e1, 1);
    element(CtorEx)(&e2, 2);
    type(Ctor)(&c);
    i = type(ContainsKey)(&c, e1);
    printf("contains=%d\n", i);
    i = type(Put)(&c, e1, e2);
    printf("i=%d\n", i);
    i = type(Put)(&c, e2, e1);
    printf("i=%d\n", i);
    i = type(Put)(&c, e2, e1);
    printf("i=%d\n", i);
    i = type(ContainsKey)(&c, e2);
    printf("contains=%d\n", i);
    v3 = type(Get)(&c, e2);
    type(Copy)(&c2, &c);
    i = type(Remove)(&c, e1);
    printf("i=%d\n", i);
    i = type(Equal)(&c, &c2);
    printf("equal=%d\n", i);
    type(Identify)(&c);
    type(Dtor)(&c);
    element(Dtor)(e1);
    element(Dtor)(e2);
    element(Dtor)(v3);
    type(Dtor)(&c2);
}


int main(int argc, char** argv) {
    ValueTypeVectorTest();
    ValueTypeListTest();
    ValueTypeQueueTest();
    ValueTypeSetTest();
    ValueTypeMapTest();
    return 0;
}
