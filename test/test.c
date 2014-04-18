#include <assert.h>
#include <memory.h>


#include "test2_auto.h"


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


void ValueTypeVectorTest() {
    ValueTypeVector vec;
    ValueType v1;
    ValueTypeVectorCtor(&vec, 3);
    v1 = ValueTypeVectorGet(&vec, 0);
    ValueTypeDtor(v1);
    ValueTypeCtor(v1);
    ValueTypeVectorSet(&vec, 0, v1);
    ValueTypeVectorSet(&vec, 2, v1);
    ValueTypeDtor(v1);
    ValueTypeVectorDtor(&vec);
}

int main(int argc, char** argv) {
    ValueTypeVectorTest();
    return 0;
}