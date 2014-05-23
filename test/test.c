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


#undef type
#define type(x) ValueTypeVector##x
#undef it
#define it(x) ValueTypeVectorIt##x


void type(Test)() {
    ValueType e1, e2;
    ValueTypeVector c1, c2;
    ValueTypeVectorIt it;
    
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
        e1 = it(Get)(&it);
        element(Dtor)(e1);
    }
    
    it(CtorEx)(&it, &c2, 0);
    while(it(Move)(&it)) {
        e1 = it(Get)(&it);
        element(Dtor)(e1);
    }

    type(Sort)(&c1);
    type(Sort)(&c2);
    
    type(Identify)(&c1);
    type(Identify)(&c2);
    
    type(Dtor)(&c1);
    type(Dtor)(&c2);
}


#undef type
#define type(x) ValueTypeList##x
#undef it
#define it(x) ValueTypeListIt##x


void type(Test)() {
    int i;
    ValueType e1, e2;
    ValueTypeList c1, c2;
    ValueTypeListIt it;
    
    type(Ctor)(&c1);
    type(Copy)(&c2, &c1);
    
    type(Equal)(&c1, &c2);
    type(Empty)(&c1);
    
    it(Ctor)(&it, &c1);
    while(it(Move)(&it)) {
        e1 = it(Get)(&it);
        element(Dtor)(e1);
    }
    
    element(CtorEx)(&e1, -1);
    element(CtorEx)(&e2, +1);
    
    /* !!! memory error detected */
    type(Push)(&c1, e1);
    type(Push)(&c2, e2);
    type(Contains)(&c1, e1);
    type(Contains)(&c2, e1);
    type(Empty)(&c1);
    
    it(Ctor)(&it, &c1);
    while(it(Move)(&it)) {
        e1 = it(Get)(&it);
        element(Dtor)(e1);
    }

    type(Identify)(&c1);
    type(Identify)(&c2);

    element(Dtor)(e1);
    element(Dtor)(e2);

    type(Dtor)(&c1);
    type(Dtor)(&c2);
}


#undef type
#define type(x) ValueTypeQueue##x
void type(Test)() {
    ValueType e1, e2;
    ValueTypeQueue c;
    printf("\n*** Queue<ValueType>\n");
    element(Ctor)(e1);
    element(Ctor)(e2);
    type(Ctor)(&c);
    type(Identify)(&c);
    type(Dtor)(&c);
    element(Dtor)(e1);
    element(Dtor)(e2);
}


#undef type
#define type(x) ValueTypeSet##x
void type(Test)() {
    int i;
    ValueType e1, e2;
    ValueTypeSet c;
    printf("\n*** HashSet<ValueType>\n");
    type(Ctor)(&c);
    element(Ctor)(e1);
    element(Ctor)(e2);
    type(Put)(&c, e1);
    i = ValueTypeSetContains(&c, e1);
    printf("contains=%d\n", i);
    type(Put)(&c, e2);
    type(Put)(&c, e1);
    element(Dtor)(e1);
    element(Dtor)(e2);
    type(Identify)(&c);
    type(Purge)(&c);
    type(Dtor)(&c);
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
