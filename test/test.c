#include <assert.h>
#include <memory.h>
#include <stdio.h>


#include "test_auto.h"


#define SIZE 16
void ValueTypeCtorEx(ValueType* self, int value) {
    assert(self);
    self->value = value;
    self->block = malloc(SIZE); assert(self->block);
}


void _ValueTypeCtor(ValueType* self) {
    ValueTypeCtorEx(self, 0);
}


void _ValueTypeDtor(ValueType* self) {
    assert(self);
    free(self->block);
}


void _ValueTypeCopy(ValueType* dst, ValueType* src) {
    assert(src);
    assert(dst);
    dst->block = malloc(SIZE); assert(dst->block);
    dst->value = src->value;
    memcpy(dst->block, src->block, SIZE);
}


int _ValueTypeEqual(ValueType* lt, ValueType* rt) {
    assert(lt);
    assert(rt);
    return lt->value == rt->value;
}


int _ValueTypeLess(ValueType* lt, ValueType* rt) {
    assert(lt);
    assert(rt);
    return lt->value < rt->value;
}


size_t _ValueTypeIdentify(ValueType* self) {
    assert(self);
    return (size_t)self->value;
}


#undef V
#define V(x) ValueType##x


#undef C
#define C(x) ValueTypeVector##x
void C(Test)() {
    ValueType v1, v2;
    ValueTypeVector c1, c2;
    printf("\n*** Vector<ValueType>\n");
    C(Ctor)(&c1, 3);
    v1 = C(Get)(&c1, 0);
    V(Dtor)(v1);
    V(Ctor)(v1);
    C(Set)(&c1, 0, v1);
    C(Set)(&c1, 2, v1);
    V(Copy)(v2, v1);
    V(Dtor)(v1);
    C(Sort)(&c1);
    C(Resize)(&c1, 2);
#if 0
    C(Resize)(&c1, 20);
#endif
    C(Set)(&c1, 0, v2);
    C(Copy)(&c2, &c1);
    C(Dtor)(&c1);
    C(Dtor)(&c2);
    V(Dtor)(v2);
}


#undef C
#define C(x) ValueTypeList##x
void C(Test)() {
    int i;
    ValueType v1, v2;
    ValueTypeList c;
    printf("\n*** List<ValueType>\n");
    V(Ctor)(v1);
    V(Ctor)(v2);
    C(Ctor)(&c);
    C(Put)(&c, v1);
    C(Put)(&c, v2);
    C(Put)(&c, v1);
    i = C(Contains)(&c, v1);
    printf("contains=%d\n", i);
    i = C(Contains)(&c, v2);
    printf("contains=%d\n", i);
    C(Dtor)(&c);
    V(Dtor)(v1);
    V(Dtor)(v2);
}


#undef C
#define C(x) ValueTypeQueue##x
void C(Test)() {
    ValueType v1, v2;
    ValueTypeQueue c;
    printf("\n*** Queue<ValueType>\n");
    V(Ctor)(v1);
    V(Ctor)(v2);
    C(Ctor)(&c);
    C(Dtor)(&c);
    V(Dtor)(v1);
    V(Dtor)(v2);
}


#undef C
#define C(x) ValueTypeSet##x
void C(Test)() {
    int i;
    ValueType v1, v2;
    ValueTypeSet c;
    printf("\n*** HashSet<ValueType>\n");
    C(Ctor)(&c);
    V(Ctor)(v1);
    V(Ctor)(v2);
    C(Put)(&c, v1);
    i = ValueTypeSetContains(&c, v1);
    printf("contains=%d\n", i);
    C(Put)(&c, v2);
    C(Put)(&c, v1);
    V(Dtor)(v1);
    V(Dtor)(v2);
    C(Purge)(&c);
    C(Dtor)(&c);
}


#undef C
#define C(x) ValueTypeMap##x
void C(Test)() {
    int i;
    ValueType v1, v2, v3;
    ValueTypeMap c, c2;
    printf("\n*** HashMap<ValueType->ValueType>\n");
    V(CtorEx)(&v1, 1);
    V(CtorEx)(&v2, 2);
    C(Ctor)(&c);
    i = C(ContainsKey)(&c, v1);
    printf("contains=%d\n", i);
    i = C(Put)(&c, v1, v2);
    printf("i=%d\n", i);
    i = C(Put)(&c, v2, v1);
    printf("i=%d\n", i);
    i = C(Put)(&c, v2, v1);
    printf("i=%d\n", i);
    i = C(ContainsKey)(&c, v2);
    printf("contains=%d\n", i);
    v3 = C(Get)(&c, v2);
    C(Copy)(&c2, &c);
    i = C(Remove)(&c, v1);
    printf("i=%d\n", i);
    i = C(Equal)(&c, &c2);
    printf("equal=%d\n", i);
    C(Dtor)(&c);
    V(Dtor)(v1);
    V(Dtor)(v2);
    V(Dtor)(v3);
    C(Dtor)(&c2);
}


int main(int argc, char** argv) {
    ValueTypeVectorTest();
    ValueTypeListTest();
    ValueTypeQueueTest();
    ValueTypeSetTest();
    ValueTypeMapTest();
    return 0;
}