#include <assert.h>
#include <stdio.h>
#include <string.h>


#include "test_auto.h"


void IntVectorTest() {
    IntVector* vec;
    printf("\n*** IntVector\n");
    vec = IntVectorNew(10);
    printf("size = %d\n", IntVectorSize(vec));
    IntVectorSet(vec, 0, 3);
    printf("vec[0] == %d\n", IntVectorGet(vec, 0));
    IntVectorDestroy(vec);
}


void IntSetTest() {
    IntSet set;
    IntSetIt it;
    printf("\n*** IntSet\n");
    IntSetCtor(&set, 10);
    printf("size = %d\n", IntSetSize(&set));
    IntSetPut(&set, -1);
    IntSetPut(&set, 3);
    IntSetPut(&set, 0);
    IntSetPut(&set, 3);
    printf("size = %d\n", IntSetSize(&set));
    IntSetPut(&set, 7);
    printf("size = %d\n", IntSetSize(&set));
    IntSetItCtor(&it, &set);
    while(IntSetItHasNext(&it)) {
        printf("- %d\n", IntSetItNext(&it));
    }
    IntSetDtor(&set);
}


size_t PCharHash(const char* s) {
    const char* p = s;
    size_t h = 0;
    while(*p++) {
        h += *p;
    }
    return h;
}


int PCharCompare(const char* lt, const char* rt) {
    return strcmp(lt, rt);
}


void PCharSetTest() {
    PCharSet set;
    PCharSetIt it;
    printf("\n*** PCharSet\n");
    PCharSetCtor(&set, 10);
    printf("size = %d\n", PCharSetSize(&set));
    PCharSetPut(&set, "cat");
    PCharSetPut(&set, "dog");
    PCharSetPut(&set, "cat");
    printf("size = %d\n", PCharSetSize(&set));
    PCharSetPut(&set, "pig");
    printf("size = %d\n", PCharSetSize(&set));
    PCharSetItCtor(&it, &set);
    while(PCharSetItHasNext(&it)) {
        printf("- %s\n", PCharSetItNext(&it));
    }
    printf("contains(pig) == %d\n", PCharSetContains(&set, "pig"));
    printf("contains(snake) == %d\n", PCharSetContains(&set, "snake"));
    PCharSetDtor(&set);
}


int main(int argc, char** argv) {
    IntVectorTest();
    IntSetTest();
    PCharSetTest();
    return 0;
}
