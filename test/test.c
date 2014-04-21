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
    return self->block;
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
    ValueTypeVectorResize(&c1, 20);
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


void ValueTypeHashTest() {
    ValueType v1, v2;
    ValueTypeHash c;
    ValueTypeHashCtor(&c);
    ValueTypeCtor(v1);
    ValueTypeCtor(v2);
    ValueTypeHashPut(&c, v1);
    ValueTypeHashPut(&c, v2);
    ValueTypeHashPut(&c, v1);
    ValueTypeDtor(v1);
    ValueTypeDtor(v2);
    ValueTypeHashPurge(&c);
    ValueTypeHashDtor(&c);
}


int main(int argc, char** argv) {
    ValueTypeVectorTest();
    ValueTypeListTest();
    ValueTypeQueueTest();
    ValueTypeHashTest();
    return 0;
}