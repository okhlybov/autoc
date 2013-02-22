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
    IntSetCtor(&set);
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
    PCharSetCtor(&set);
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


void PChar2IntMapTest() {
    PChar2IntMap* map;
    PChar2IntMapIt it;
    printf("\n*** PChar2IntMap\n");
    map = PChar2IntMapNew();
    PChar2IntMapPut(map, "cat", 1);
    PChar2IntMapPut(map, "dog", 2);
    PChar2IntMapPut(map, "cat", 0);
    PChar2IntMapPut(map, "pig", 0);
    printf("size = %d\n", PChar2IntMapSize(map));
    PChar2IntMapItCtor(&it, map);
    while(PChar2IntMapItHasNext(&it)) {
        PChar2IntMapEntry entry = PChar2IntMapItNext(&it);
        printf("- %s --> %d\n", entry.key, entry.value);
    }
    PChar2IntMapDestroy(map);
}


struct Box {
    size_t refs;
    int contents;
};


Box* BoxNew() {
    Box* box = malloc(sizeof(Box));
    box->refs = 0;
    box->contents = -1;
    return box;
}


Box* BoxMake(int contents) {
    Box* box = BoxNew();
    box->contents = contents;
    return box;
}


Box* BoxAssign(Box* box) {
    ++box->refs;
    return box;
}


int BoxCompare(Box* lt, Box* rt) {
    return (lt->contents == rt->contents) ? 0 : (lt->contents < rt->contents ? +1 : -1);
}


size_t BoxHash(Box* box) {
    return box->contents;
}


void BoxDestroy(Box* box) {
    if(!--box->refs) free(box);
}


void BoxSetTest() {
    BoxSet* set;
    Box *b1, *b2, *b4;
    printf("\n*** BoxSet\n");
    b1 = BoxAssign(BoxMake(1));
    b2 = BoxAssign(BoxMake(2));
    b4 = BoxAssign(b2);
    set = BoxSetNew();
    BoxSetPut(set, b1);
    BoxSetPut(set, BoxMake(3));
    BoxSetPut(set, b2);
    BoxSetPut(set, b1);
    printf("size = %d\n", BoxSetSize(set));
    BoxDestroy(b1);
    BoxSetDestroy(set);
    BoxDestroy(b2);
    BoxDestroy(b4);
}


void BoxVectorTest() {
    BoxVector* vec;
    Box* b1;
    printf("\n*** BoxVector\n");
    b1 = BoxAssign(BoxNew());
    vec = BoxVectorNew(10);
    printf("size = %d\n", BoxVectorSize(vec));
    BoxVectorSet(vec, 7, b1);
    BoxVectorResize(vec, 5);
    printf("size = %d\n", BoxVectorSize(vec));
    BoxVectorSet(vec, 3, BoxNew());
    BoxVectorResize(vec, 10);
    printf("size = %d\n", BoxVectorSize(vec));
    BoxVectorDestroy(vec);
    BoxDestroy(b1);
}


void BoxListTest() {
    BoxList* list;
    Box *b1,*b2;
    printf("\n*** BoxList\n");
    list = BoxListNew();
    b1 = BoxAssign(BoxNew());
    BoxListPrepend(list, BoxMake(2));
    BoxListAppend(list, BoxMake(1));
    printf("size = %d\n", BoxListSize(list));
    printf("contains([-1]) == %d\n", BoxListContains(list, b1));
    BoxListPrune(list);
    BoxListPrepend(list, BoxMake(7));
    BoxListAppend(list, b1);
    BoxListPrepend(list, b1);
    b2 = BoxAssign(BoxMake(3));
    printf("size = %d\n", BoxListSize(list));
    printf("contains([-1]) == %d\n", BoxListContains(list, b1));
    BoxListReplaceAll(list, b1, b2);
    printf("contains([-1]) == %d\n", BoxListContains(list, b1));
    printf("contains([3]) == %d\n", BoxListContains(list, b2));
    BoxListPruneFirst(list);
    printf("size = %d\n", BoxListSize(list));
    BoxListDestroy(list);
    BoxDestroy(b1);
    BoxDestroy(b2);
}


int main(int argc, char** argv) {
    IntVectorTest();
    IntSetTest();
    PCharSetTest();
    PChar2IntMapTest();
    BoxSetTest();
    BoxVectorTest();
    BoxListTest();
    return 0;
}
