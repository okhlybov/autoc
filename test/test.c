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
    size_t h = 0;
    while(*s++) {
        h += *s;
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
    printf("contains('pig') == %d\n", PCharSetContains(&set, "pig"));
    printf("contains('snake') == %d\n", PCharSetContains(&set, "snake"));
    PCharSetDtor(&set);
}


void PChar2IntMapTest() {
    PChar2IntMap* map;
    PChar2IntMapIt it;
    printf("\n*** PChar2IntMap\n");
    map = PChar2IntMapNew(16);
    PChar2IntMapPut(map, "cat", 1);
    PChar2IntMapPut(map, "dog", 2);
    PChar2IntMapPut(map, "cat", 0);
    PChar2IntMapPut(map, "pig", 0);
    printf("size = %d\n", PChar2IntMapSize(map));
    PChar2IntMapItCtor(&it, map);
    while(PChar2IntMapItHasNext(&it)) {
        PChar2IntMapEntry entry = PChar2IntMapItNext(&it);
        printf("- '%s' -> %d\n", entry.key, entry.value);
    }
    PChar2IntMapDestroy(map);
}


int main(int argc, char** argv) {
    IntVectorTest();
    IntSetTest();
    PCharSetTest();
    PChar2IntMapTest();
    return 0;
}
