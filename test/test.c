#include <assert.h>
#include <memory.h>


#include "test_auto.h"


void _ValueTypeCtor(ValueType* self) {
    assert(self);
    self->size = 1;
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


void ValueTypeVectorTest() {
    ValueType v1, v2;
    ValueTypeVector vec1, vec2;
    ValueTypeVectorCtor(&vec1, 3);
    v1 = ValueTypeVectorGet(&vec1, 0);
    ValueTypeDtor(v1);
    ValueTypeCtor(v1);
    ValueTypeVectorSet(&vec1, 0, v1);
    ValueTypeVectorSet(&vec1, 2, v1);
    ValueTypeCopy(v2, v1);
    ValueTypeDtor(v1);
    ValueTypeVectorSort(&vec1);
    ValueTypeVectorResize(&vec1, 2);
    ValueTypeVectorSet(&vec1, 0, v2);
    ValueTypeVectorCopy(&vec2, &vec1);
    ValueTypeVectorDtor(&vec1);
    ValueTypeVectorDtor(&vec2);
    ValueTypeDtor(v2);
}


void ValueTypeListTest() {
    ValueType v1, v2;
    ValueTypeList l;
}


void ValueTypeQueueTest() {
    ValueType v1, v2;
    ValueTypeQueue q;
}


int main(int argc, char** argv) {
    ValueTypeVectorTest();
    ValueTypeListTest();
    ValueTypeQueueTest();
    return 0;
}