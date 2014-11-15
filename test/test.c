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


static void type(Test)() {
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


static void type(Test)() {
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
static void type(Test)() {
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


static void type(Test)() {
    ValueType e1, e2, e3;
    Type c1, c2, cc1, cc2;
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

    type(Put)(&c2, e1);
    type(Put)(&c2, e2);
    type(Put)(&c2, e3);
    
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
    
    {
        type(Copy)(&cc1, &c1);
        type(Copy)(&cc2, &c2);
        type(Retain)(&cc1, &cc2);
        type(Dtor)(&cc1);
        type(Dtor)(&cc2);
    }
    
    {
        type(Copy)(&cc1, &c1);
        type(Copy)(&cc2, &c2);
        type(Retain)(&cc2, &cc1);
        type(Dtor)(&cc1);
        type(Dtor)(&cc2);
    }

    {
        type(Copy)(&cc1, &c1);
        type(Copy)(&cc2, &c2);
        type(Include)(&cc1, &cc2);
        type(Dtor)(&cc1);
        type(Dtor)(&cc2);
    }
    
    {
        type(Copy)(&cc1, &c1);
        type(Copy)(&cc2, &c2);
        type(Include)(&cc2, &cc1);
        type(Dtor)(&cc1);
        type(Dtor)(&cc2);
    }

    {
        type(Copy)(&cc1, &c1);
        type(Copy)(&cc2, &c2);
        type(Exclude)(&cc1, &cc2);
        type(Dtor)(&cc1);
        type(Dtor)(&cc2);
    }
    
    {
        type(Copy)(&cc1, &c1);
        type(Copy)(&cc2, &c2);
        type(Exclude)(&cc2, &cc1);
        type(Dtor)(&cc1);
        type(Dtor)(&cc2);
    }

    {
        type(Copy)(&cc1, &c1);
        type(Copy)(&cc2, &c2);
        type(Invert)(&cc1, &cc2);
        type(Dtor)(&cc1);
        type(Dtor)(&cc2);
    }
    
    {
        type(Copy)(&cc1, &c1);
        type(Copy)(&cc2, &c2);
        type(Invert)(&cc2, &cc1);
        type(Dtor)(&cc1);
        type(Dtor)(&cc2);
    }

    type(Identify)(&c1);
    type(Identify)(&c2);

    type(Purge)(&c1);
    type(Dtor)(&c1);
    type(Dtor)(&c2);
}


#undef Type
#define Type ValueTypeMap
#undef TypeIt
#define TypeIt ValueTypeMapIt
#undef type
#define type(x) ValueTypeMap##x
#undef it
#define it(x) ValueTypeMapIt##x


static void type(Test)() {
    ValueType e1, e2, e3;
    Type c1, c2;
    TypeIt it;
    
    element(CtorEx)(&e1, -1);
    element(CtorEx)(&e2, +1);
    element(CtorEx)(&e3, 0);

    type(Ctor)(&c1);
    type(Put)(&c1, e1, e3);
    type(Put)(&c1, e2, e3);
    type(Copy)(&c2, &c1);
    
    type(Put)(&c1, e1, e2);
    type(Put)(&c2, e2, e1);

    {
        int i;
        ValueType e;
        for(i = 0; i < 100; ++i) {
            element(CtorEx)(&e, i);
            type(Put)(&c1, e, e);
            element(Dtor)(e);
        }
        for(i = 0; i < 100; i += 2) {
            element(CtorEx)(&e, i);
            type(Remove)(&c1, e);
            element(Dtor)(e);
        }
        for(i = 1; i < 10; ++i) {
            ValueType k;
            element(CtorEx)(&k, i);
            element(CtorEx)(&e, -i);
            type(Replace)(&c1, k, e);
            element(Dtor)(k);
            element(Dtor)(e);
        }
    }
    
    it(Ctor)(&it, &c1);
    while(it(Move)(&it)) {
        ValueType k = it(GetKey)(&it), e = it(GetElement)(&it);
        element(Dtor)(k);
        element(Dtor)(e);
    }

    element(Dtor)(e1);
    element(Dtor)(e2);
    element(Dtor)(e3);

    type(Equal)(&c1, &c2);
    type(Empty)(&c1);
    type(Size)(&c1);
    
    type(Identify)(&c1);
    type(Identify)(&c2);

    type(Purge)(&c1);
    type(Dtor)(&c1);
    type(Dtor)(&c2);
}


#undef Type
#define Type IntSet
#undef TypeIt
#define TypeIt IntSetIt
#undef type
#define type(x) IntSet##x
#undef it
#define it(x) IntSetIt##x


/* {1,2,3} & {2,3,4} == {2,3} */
static void type(TestAnd)() {
    Type r, c1, c2, cc1, cc2;
    
    type(Ctor)(&r);
    type(Ctor)(&c1);
    type(Ctor)(&c2);

    assert(type(Empty)(&r));
    assert(type(Empty)(&c1));
    assert(type(Empty)(&c2));

    type(Put)(&c1, 1); type(Put)(&c1, 3);
    type(Put)(&c1, 2);
    type(Put)(&c1, 3); type(Put)(&c1, 1);

    assert(type(Size)(&c1) == 3);

    type(Copy)(&cc1, &c1);

    type(Put)(&c2, 2);
    type(Put)(&c2, 3);
    type(Put)(&c2, 4);

    assert(type(Size)(&c2) == 3);

    type(Copy)(&cc2, &c2);

    assert(!type(Equal)(&c1, &c2));
    assert(!type(Equal)(&c2, &c1));

    type(Retain)(&c1, &c2);
    type(Retain)(&cc2, &cc1);

    assert(type(Size)(&c1) == 2);
    assert(type(Size)(&cc2) == 2);

    type(Put)(&r, 3);
    type(Put)(&r, 2);

    assert(type(Size)(&r) == 2);

    assert(!type(Empty)(&r));
    assert(!type(Empty)(&c1));
    assert(!type(Empty)(&c2));

    assert(type(Equal)(&c1, &r));
    assert(type(Equal)(&r, &c1));

    assert(type(Equal)(&cc2, &c1));
    assert(type(Equal)(&c1, &cc2));

    type(Dtor)(&r);
    type(Dtor)(&c1);
    type(Dtor)(&c2);
    type(Dtor)(&cc1);
    type(Dtor)(&cc2);
}


/* {1,2,3} | {2,3,4} == {1,2,3,4} */
static void type(TestOr)() {
    Type r, c1, c2, cc1, cc2;
    
    type(Ctor)(&r);
    type(Ctor)(&c1);
    type(Ctor)(&c2);

    assert(type(Empty)(&r));
    assert(type(Empty)(&c1));
    assert(type(Empty)(&c2));

    type(Put)(&c1, 1); type(Put)(&c1, 3);
    type(Put)(&c1, 2);
    type(Put)(&c1, 3); type(Put)(&c1, 1);

    assert(type(Size)(&c1) == 3);

    type(Copy)(&cc1, &c1);

    type(Put)(&c2, 2);
    type(Put)(&c2, 3);
    type(Put)(&c2, 4);

    assert(type(Size)(&c2) == 3);

    type(Copy)(&cc2, &c2);

    assert(!type(Equal)(&c1, &c2));
    assert(!type(Equal)(&c2, &c1));

    type(Include)(&c1, &c2);
    type(Include)(&cc2, &cc1);

    assert(type(Size)(&c1) == 4);
    assert(type(Size)(&cc2) == 4);

    type(Put)(&r, 3);
    type(Put)(&r, 2);
    type(Put)(&r, 1);
    type(Put)(&r, 4);

    assert(type(Size)(&r) == 4);

    assert(!type(Empty)(&r));
    assert(!type(Empty)(&c1));
    assert(!type(Empty)(&c2));

    assert(type(Equal)(&c1, &r));
    assert(type(Equal)(&r, &c1));

    assert(type(Equal)(&cc2, &c1));
    assert(type(Equal)(&c1, &cc2));

    type(Dtor)(&r);
    type(Dtor)(&c1);
    type(Dtor)(&c2);
    type(Dtor)(&cc1);
    type(Dtor)(&cc2);
}


/* {1,2,3} ^ {2,3,4} == {1,4} */
static void type(TestXor)() {
    Type r, c1, c2, cc1, cc2;
    
    type(Ctor)(&r);
    type(Ctor)(&c1);
    type(Ctor)(&c2);

    assert(type(Empty)(&r));
    assert(type(Empty)(&c1));
    assert(type(Empty)(&c2));

    type(Put)(&c1, 1); type(Put)(&c1, 3);
    type(Put)(&c1, 2);
    type(Put)(&c1, 3); type(Put)(&c1, 1);

    assert(type(Size)(&c1) == 3);

    type(Copy)(&cc1, &c1);

    type(Put)(&c2, 2);
    type(Put)(&c2, 3);
    type(Put)(&c2, 4);

    assert(type(Size)(&c2) == 3);

    type(Copy)(&cc2, &c2);

    assert(!type(Equal)(&c1, &c2));
    assert(!type(Equal)(&c2, &c1));

    type(Invert)(&c1, &c2);
    type(Invert)(&cc2, &cc1);

    assert(type(Size)(&c1) == 2);
    assert(type(Size)(&cc2) == 2);

    type(Put)(&r, 4);
    type(Put)(&r, 1);

    assert(type(Size)(&r) == 2);

    assert(!type(Empty)(&r));
    assert(!type(Empty)(&c1));
    assert(!type(Empty)(&c2));

    assert(type(Equal)(&c1, &r));
    assert(type(Equal)(&r, &c1));

    assert(type(Equal)(&cc2, &c1));
    assert(type(Equal)(&c1, &cc2));

    type(Dtor)(&r);
    type(Dtor)(&c1);
    type(Dtor)(&c2);
    type(Dtor)(&cc1);
    type(Dtor)(&cc2);
}


/* {1,2,3} - {2,3,4} == {1} */
static void type(TestNot1)() {
    Type r, c1, c2, cc1, cc2;
    
    type(Ctor)(&r);
    type(Ctor)(&c1);
    type(Ctor)(&c2);

    assert(type(Empty)(&r));
    assert(type(Empty)(&c1));
    assert(type(Empty)(&c2));

    type(Put)(&c1, 1); type(Put)(&c1, 3);
    type(Put)(&c1, 2);
    type(Put)(&c1, 3); type(Put)(&c1, 1);

    assert(type(Size)(&c1) == 3);

    type(Copy)(&cc1, &c1);

    type(Put)(&c2, 2);
    type(Put)(&c2, 3);
    type(Put)(&c2, 4);

    assert(type(Size)(&c2) == 3);

    type(Copy)(&cc2, &c2);

    assert(!type(Equal)(&c1, &c2));
    assert(!type(Equal)(&c2, &c1));

    type(Exclude)(&c1, &c2);
    type(Exclude)(&cc2, &cc1);

    assert(type(Size)(&c1) == 1);
    assert(type(Size)(&cc2) == 1);

    type(Put)(&r, 1);

    assert(type(Size)(&r) == 1);

    assert(!type(Empty)(&r));
    assert(!type(Empty)(&c1));
    assert(!type(Empty)(&c2));

    assert(type(Equal)(&c1, &r));
    assert(type(Equal)(&r, &c1));

    assert(!type(Equal)(&cc2, &c1));
    assert(!type(Equal)(&c1, &cc2));

    type(Dtor)(&r);
    type(Dtor)(&c1);
    type(Dtor)(&c2);
    type(Dtor)(&cc1);
    type(Dtor)(&cc2);
}


/* {1,2,3} - {1,2,3,4} == {} */
static void type(TestNot2)() {
    Type r, c1, c2;
    
    type(Ctor)(&r);
    type(Ctor)(&c1);
    type(Ctor)(&c2);

    assert(type(Empty)(&r));
    assert(type(Empty)(&c1));
    assert(type(Empty)(&c2));

    type(Put)(&c1, 1); type(Put)(&c1, 3);
    type(Put)(&c1, 2);
    type(Put)(&c1, 3); type(Put)(&c1, 1);

    assert(type(Size)(&c1) == 3);

    type(Put)(&c2, 1);
    type(Put)(&c2, 2);
    type(Put)(&c2, 3);
    type(Put)(&c2, 4);

    assert(type(Size)(&c2) == 4);

    assert(!type(Equal)(&c1, &c2));
    assert(!type(Equal)(&c2, &c1));

    type(Exclude)(&c1, &c2);

    assert(type(Size)(&c1) == 0);

    assert(type(Size)(&r) == 0);

    assert(type(Empty)(&r));
    assert(type(Empty)(&c1));
    assert(!type(Empty)(&c2));

    assert(type(Equal)(&c1, &r));
    assert(type(Equal)(&r, &c1));

    type(Dtor)(&r);
    type(Dtor)(&c1);
    type(Dtor)(&c2);
}


#undef Type
#define Type IntStrMap
#undef TypeIt
#define TypeIt IntStrMapIt
#undef type
#define type(x) IntStrMap##x
#undef it
#define it(x) IntStrMapIt##x


static const char* zero = "zero";
static const char* one = "one";
static const char* two = "two";


static void type(Test)() {
    Type c1, c2;
    TypeIt it;
    int i;
    
    type(Ctor)(&c1);
    type(Ctor)(&c2);

    assert(type(Empty)(&c1));
    assert(type(Empty)(&c2));
    assert(type(Equal)(&c1, &c2));
    
    assert(type(Put)(&c1, 0, zero));
    assert(type(Put)(&c1, 1, one));
    assert(type(Put)(&c1, 2, two));
    assert(!type(Put)(&c1, 2, two));
    
    assert(type(Put)(&c2, 2, two));
    assert(type(Put)(&c2, 0, zero));
    assert(type(Put)(&c2, 1, one));
    assert(!type(Put)(&c2, 0, zero));

    assert(!type(Empty)(&c1));
    assert(!type(Empty)(&c2));
    assert(type(Size)(&c1) == type(Size)(&c2));
    assert(type(Equal)(&c1, &c2));
    
    assert(type(ContainsKey)(&c1, 0));
    assert(type(Remove)(&c1, 0));
    assert(!type(Remove)(&c1, 0));
    assert(!type(ContainsKey)(&c1, 0));
    assert(type(ContainsKey)(&c2, 2));
    assert(type(Remove)(&c2, 2));
    assert(!type(ContainsKey)(&c2, 2));
    assert(type(Size)(&c1) == type(Size)(&c2));
    assert(!type(Equal)(&c1, &c2));

    type(Purge)(&c1);
    
    assert(type(Put)(&c1, 0, zero));
    assert(type(Put)(&c1, 1, one));
    assert(type(Put)(&c1, 2, two));

    assert(type(Replace)(&c1, 0, two));
    assert(type(Replace)(&c1, 2, zero));
    
    assert(type(Get)(&c1, 0) == two);
    assert(type(Get)(&c1, 2) == zero);
    assert(type(Get)(&c1, 1) == one);
    
    i = 0;
    it(Ctor)(&it, &c1);
    while(it(Move)(&it)) {
        int k;
        const char* e;
        k = it(GetKey)(&it);
        e = it(Get)(&it);
        ++i;
    }
    assert(i == 3);
    
    type(Purge)(&c2);
    type(Dtor)(&c1);
    type(Dtor)(&c2);
}


#undef Type
#define Type ListIntSet
#undef TypeIt
#define TypeIt ListIntSetIt
#undef type
#define type(x) ListIntSet##x
#undef it
#define it(x) ListIntSetIt##x
#undef Element
#define Element IntSet
#undef element
#define element(x) IntSet##x


static void type(Test)() {
    Type c1, c2;
    Element e;
    
    type(Ctor)(&c1);
    type(Ctor)(&c2);
    
    element(Ctor)(&e);
    type(Push)(&c1, e);
    element(Put)(&e, 3);
    element(Put)(&e, 2);
    element(Put)(&e, 1);
    type(Push)(&c2, e);
    element(Dtor)(&e);
    
    type(Dtor)(&c1);
    type(Dtor)(&c2);
}


#undef Type
#define Type Int
#undef type
#define type(x) Int##x


static void PIntTest() {
    int *c1, *c2;
    c1 = type(New)(); *c1 = 1;
    c2 = type(New)(); *c2 = 2;
    assert(*c1 != *c2);
    type(Free)(c2);
    c2 = type(Ref)(c1);
    assert(*c1 == *c2);
    type(Free)(c1);
    type(Free)(c2);
}


#undef Type
#define Type ValueType
#undef type
#define type(x) ValueType##x


static void PValueTypeTest() {
    ValueType *c1, *c2;
    c1 = type(New)();
    c2 = type(New)();
    type(Free)(c2);
    c2 = type(Ref)(c1);
    type(Free)(c1);
    type(Free)(c2);
}


/* List<Vector<ValueType*>*> */
#undef Type
#define Type ListPVectorValue
#undef TypeIt
#define TypeIt ListPVectorValueIt
#undef type
#define type(x) ListPVectorValue##x
#undef it
#define it(x) ListPVectorValueIt##x
#undef Element
#define Element PVectorValue
#undef element
#define element(x) PVectorValue##x


static void type(Test)() {
    Type c1, c2;
    Element *e1, *e2;
    ValueType *v1, *v2;
    
    type(Ctor)(&c1);
    type(Ctor)(&c2);
    
    e1 = element(New)(3);
    
    element(Set)(e1, 1, v1 = ValueTypeNew());
    
    e2 = element(Ref)(e1);
    
    assert(element(Equal)(e1, e2));
    
    element(Set)(e2, 0, v2 = ValueTypeRef(v1));
    
    type(Push)(&c1, e1);
    
    element(Free)(e1);
    element(Free)(e2);
    
    type(Dtor)(&c1);
    type(Dtor)(&c2);
    
    ValueTypeFree(v1);
    ValueTypeFree(v2);
}


int main(int argc, char** argv) {
    ValueTypeVectorTest();
    ValueTypeListTest();
    ValueTypeQueueTest();
    ValueTypeSetTest();
    ValueTypeMapTest();
    IntSetTestAnd();
    IntSetTestOr();
    IntSetTestXor();
    IntSetTestNot1();
    IntSetTestNot2();
    IntStrMapTest();
    ListIntSetTest();
    PIntTest();
    PValueTypeTest();
    ListPVectorValueTest();
    return 0;
}
