#include <assert.h>
#include <memory.h>


#include "test_auto.h"


void _ValueTypeCtor(ValueType* self) {
    assert(self);
    self->size = 16;
    self->block = malloc(self->size); assert(self->block);
}


void _ValueTypeDtor(ValueType* self) {
    assert(self);
    free(self->block);
}


void _ValueTypeCopy(ValueType* dst, ValueType* src) {
    assert(src);
    assert(dst);
    dst->size = src->size;
    dst->block = malloc(dst->size); assert(dst->block);
    memcpy(dst->block, src->block, dst->size);
}


int _ValueTypeEqual(ValueType* lt, ValueType* rt) {
    assert(lt);
    assert(rt);
    return lt->block == rt->block;
}


int _ValueTypeLess(ValueType* lt, ValueType* rt) {
    assert(lt);
    assert(rt);
    return lt->block < rt->block;
}


size_t _ValueTypeIdentify(ValueType* self) {
    assert(self);
    return (size_t)self->block;
}


void ValueTypeVectorTest() {
    ValueType v1, v2;
    ValueTypeVector c1, c2;
    ValueTypeVectorCtor(&c1, 3);
    v1 = ValueTypeVectorGet(&c1, 0);
    ValueTypeDtor(v1);
    ValueTypeCtor(v1);
    ValueTypeVectorSet(&c1, 0, v1);
    ValueTypeVectorSet(&c1, 2, v1);
    ValueTypeCopy(v2, v1);
    ValueTypeDtor(v1);
    ValueTypeVectorSort(&c1);
    ValueTypeVectorResize(&c1, 2);
#if 0
    ValueTypeVectorResize(&c1, 20);
#endif
    ValueTypeVectorSet(&c1, 0, v2);
    ValueTypeVectorCopy(&c2, &c1);
    ValueTypeVectorDtor(&c1);
    ValueTypeVectorDtor(&c2);
    ValueTypeDtor(v2);
}


void ValueTypeListTest() {
    ValueType v1, v2;
    ValueTypeList c;
    ValueTypeCtor(v1);
    ValueTypeCtor(v2);
    ValueTypeListCtor(&c);
    ValueTypeListDtor(&c);
    ValueTypeDtor(v1);
    ValueTypeDtor(v2);
}


void ValueTypeQueueTest() {
    ValueType v1, v2;
    ValueTypeQueue c;
    ValueTypeCtor(v1);
    ValueTypeCtor(v2);
    ValueTypeQueueCtor(&c);
    ValueTypeQueueDtor(&c);
    ValueTypeDtor(v1);
    ValueTypeDtor(v2);
}


void ValueTypeSetTest() {
    ValueType v1, v2;
    ValueTypeSet c;
    ValueTypeSetCtor(&c);
    ValueTypeCtor(v1);
    ValueTypeCtor(v2);
    ValueTypeSetPut(&c, v1);
    ValueTypeSetPut(&c, v2);
    ValueTypeSetPut(&c, v1);
    ValueTypeDtor(v1);
    ValueTypeDtor(v2);
    ValueTypeSetPurge(&c);
    ValueTypeSetDtor(&c);
}


void ValueTypeMapTest() {
    int i;
    ValueType v1, v2, v3;
    ValueTypeMap c;
    ValueTypeCtor(v1);
    ValueTypeCtor(v2);
    ValueTypeMapCtor(&c);
    ValueTypeMapContainsKey(&c, v1);
    i = ValueTypeMapPut(&c, v1, v2);
    printf("i=%d\n", i);
    i = ValueTypeMapPut(&c, v2, v1);
    printf("i=%d\n", i);
    ValueTypeMapContainsKey(&c, v2);
    v3 = ValueTypeMapGet(&c, v2);
    ValueTypeMapDtor(&c);
    ValueTypeDtor(v1);
    ValueTypeDtor(v2);
    ValueTypeDtor(v3);
}


int main(int argc, char** argv) {
    ValueTypeVectorTest();
    ValueTypeListTest();
    ValueTypeQueueTest();
    ValueTypeSetTest();
    ValueTypeMapTest();
    return 0;
}