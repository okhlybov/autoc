#include <assert.h>
#include <stdio.h>
#include <string.h>


#include "test_auto.h"


void PrintIntVector(IntVector* vec) {
    IntVectorIt it;
    IntVectorItCtor(&it, vec);
    while(IntVectorItHasNext(&it)) {
        printf("%d ", IntVectorItNext(&it));
    }
    printf("\n");
}


void IntVectorTest() {
    IntVector* vec;
    printf("\n*** IntVector\n");
    vec = IntVectorAssign(IntVectorNew(10));
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


int PCharEqual(const char* lt, const char* rt) {
    return strcmp(lt, rt) == 0;
}


void PrintPCharSet(PCharSet* set) {
    PCharSetIt it;
    PCharSetItCtor(&it, set);
    while(PCharSetItHasNext(&it)) {
        printf("%s ", PCharSetItNext(&it));
    }
    printf("\n");
}


void PCharSetTest() {
    PCharSet set;
    PCharSetIt it;
    printf("\n*** PCharSet (I)\n");
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
    PCharSetPurge(&set);
    PCharSetDtor(&set);
}


void PCharSetTest2() {
    PCharSet *a, *b, *c;
    printf("\n*** PCharSet (II)\n");
    a = PCharSetAssign(PCharSetNew());
    b = PCharSetAssign(PCharSetNew());
    c = PCharSetAssign(PCharSetNew());
    PCharSetPut(a, "cat");
    PCharSetPut(a, "dog");
    PCharSetPut(a, "pig");
    PCharSetPut(a, "rat");
    PCharSetPut(b, "mouse");
    PCharSetPut(b, "snake");
    PCharSetPut(b, "rat");

    PCharSetPurge(c);
    PCharSetOr(c, a);
    PCharSetAnd(c, b);
    PrintPCharSet(c);

    PCharSetPurge(c);
    PCharSetOr(c, a);
    PCharSetOr(c, b);
    PrintPCharSet(c);

    PCharSetPurge(c);
    PCharSetOr(c, a);
    PCharSetXor(c, b);
    PrintPCharSet(c);

    PCharSetDestroy(a);
    PCharSetDestroy(b);
    PCharSetDestroy(c);
}


void PChar2IntMapTest() {
    PChar2IntMap* map;
    PChar2IntMapIt it;
    printf("\n*** PChar2IntMap\n");
    map = PChar2IntMapAssign(PChar2IntMapNew());
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
    PChar2IntMapPurge(map);
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
    assert(box);
    ++box->refs;
    return box;
}


int BoxEqual(Box* lt, Box* rt) {
    assert(lt);
    assert(rt);
    return lt->contents == rt->contents;
}


size_t BoxHash(Box* box) {
    assert(box);
    return box->contents;
}


void BoxDestroy(Box* box) {
    assert(box);
    if(!--box->refs) free(box);
}


void BoxSetTest() {
    int i;
    BoxSet* set;
    Box *b1, *b2, *b4;
    printf("\n*** BoxSet\n");
    b1 = BoxAssign(BoxMake(1));
    b2 = BoxAssign(BoxMake(2));
    b4 = BoxAssign(b2);
    set = BoxSetAssign(BoxSetNew());
    BoxSetPut(set, b1);
    BoxSetPut(set, BoxMake(3));
    BoxSetPut(set, b2);
    BoxSetPut(set, b1);
    printf("size = %d\n", BoxSetSize(set));
    BoxDestroy(b1);
    for(i = 0; i < 100; ++i) {
        BoxSetPut(set, BoxMake(i));
    }
    printf("size = %d\n", BoxSetSize(set));
    BoxSetPurge(set);
    BoxSetDestroy(set);
    BoxDestroy(b2);
    BoxDestroy(b4);
}


void BoxVectorTest() {
    BoxVector* vec;
    Box* b1;
    printf("\n*** BoxVector\n");
    b1 = BoxAssign(BoxNew());
    vec = BoxVectorAssign(BoxVectorNew(10));
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
    list = BoxListAssign(BoxListNew());
    b1 = BoxAssign(BoxNew());
    BoxListAdd(list, BoxMake(2));
    BoxListAdd(list, BoxMake(1));
    printf("size = %d\n", BoxListSize(list));
    printf("contains([-1]) == %d\n", BoxListContains(list, b1));
    BoxListChop(list);
    BoxListRemove(list, BoxMake(1));
    BoxListRemove(list, BoxMake(2));
    BoxListRemove(list, BoxMake(3));
    printf("size = %d\n", BoxListSize(list));
    BoxListPurge(list);
    BoxListAdd(list, BoxMake(7));
    BoxListAdd(list, b1);
    BoxListAdd(list, b1);
    b2 = BoxAssign(BoxMake(3));
    printf("size = %d\n", BoxListSize(list));
    printf("contains([-1]) == %d\n", BoxListContains(list, b1));
    BoxListReplaceAll(list, b1, b2);
    printf("contains([-1]) == %d\n", BoxListContains(list, b1));
    printf("contains([3]) == %d\n", BoxListContains(list, b2));
    BoxListChop(list);
    printf("size = %d\n", BoxListSize(list));
    BoxListDestroy(list);
    BoxDestroy(b1);
    BoxDestroy(b2);
}


void Box2BoxMapTest() {
    int i;
    Box2BoxMap* map, *map2;
    Box *b1, *b2;
    printf("\n*** Box2BoxMap\n");
    map = Box2BoxMapAssign(Box2BoxMapNew());
    b1 = BoxAssign(BoxMake(-1));
    b2 = BoxAssign(b1);
    Box2BoxMapContainsKey(map, BoxMake(3));
    Box2BoxMapContainsKey(map, b1);
    Box2BoxMapReplace(map, BoxMake(-1), BoxMake(-1));
    Box2BoxMapReplace(map, BoxMake(-2), BoxMake(-2));
    Box2BoxMapPut(map, b1, BoxMake(3));
    Box2BoxMapPut(map, BoxMake(2), BoxMake(2));
    Box2BoxMapPut(map, BoxMake(1), BoxMake(1));
    Box2BoxMapReplace(map, BoxMake(1), BoxMake(-3));
    printf("size = %d\n", Box2BoxMapSize(map));
    for(i = 0; i < 100; ++i) {
        Box2BoxMapPut(map, BoxMake(i), BoxMake(-i));
    }
    printf("size = %d\n", Box2BoxMapSize(map));
    i = -2; printf("map[Box(%d)] == Box(%d)\n", i, Box2BoxMapGet(map, BoxMake(i))->contents);
    i = 3; printf("map[Box(%d)] == Box(%d)\n", i, Box2BoxMapGet(map, BoxMake(i))->contents);
    printf("contains([99]) == %d\n", Box2BoxMapContainsKey(map, BoxMake(+99)));
    Box2BoxMapRemove(map, BoxMake(+99));
    printf("contains([99]) == %d\n", Box2BoxMapContainsKey(map, BoxMake(+99)));
    map2 = Box2BoxMapAssign(map);
    Box2BoxMapRemove(map2, BoxMake(-99));
    Box2BoxMapPurge(map);
    Box2BoxMapPut(map2, BoxMake(3), b2);
    BoxDestroy(b2);
    printf("size = %d\n", Box2BoxMapSize(map2));
    Box2BoxMapDestroy(map2);
    Box2BoxMapDestroy(map);
    BoxDestroy(b1);
}


void PChar2IntVectorMapTest() {
    int i;
    PChar2IntVectorMap* map;
    IntVector* vec;
    printf("\n*** PChar2IntVectorMap\n");
    map = PChar2IntVectorMapAssign(PChar2IntVectorMapNew());
    PChar2IntVectorMapPut(map, "zero", IntVectorNew(3));
    PChar2IntVectorMapPut(map, "one", IntVectorNew(3));
    vec = PChar2IntVectorMapGet(map, "one"); for(i = 0; i < IntVectorSize(vec); ++i) {
        IntVectorSet(vec, i, i);
    }
    printf("size = %d\n", IntVectorSize(vec));
    PrintIntVector(vec);
    IntVectorResize(PChar2IntVectorMapGet(map, "one"), 5);
    printf("size = %d\n", IntVectorSize(vec));
    PrintIntVector(vec);
    PChar2IntVectorMapDestroy(map);
}


void PrintPCharQueue(PCharQueue* queue, int fwd) {
    PCharQueueIt it;
    PCharQueueItCtor(&it, queue, fwd);
    while(PCharQueueItHasNext(&it)) {
        printf("%s ", PCharQueueItNext(&it));
    }
    printf("\n");
}


void PCharQueueTest() {
    PCharQueue* queue;
    printf("\n*** PCharQueue\n");
    queue = PCharQueueAssign(PCharQueueNew());
    PCharQueuePrepend(queue, "one");
    PCharQueuePrepend(queue, "zero");
    PCharQueueAppend(queue, "two");
    PCharQueueAppend(queue, "three");
    printf("contains(zero) == %d\n", PCharQueueContains(queue, "zero"));
    printf("contains(four) == %d\n", PCharQueueContains(queue, "four"));
    PrintPCharQueue(queue, 1);
    PrintPCharQueue(queue, 0);
    PCharQueueRemove(queue, "two");
    printf("head = %s\n", PCharQueueHead(queue));
    printf("tail = %s\n", PCharQueueTail(queue));
    PCharQueueChopTail(queue);
    PCharQueueChopHead(queue);
    PrintPCharQueue(queue, 1);
    PCharQueuePurge(queue);
    PCharQueueAppend(queue, "zero");
    printf("head = %s\n", PCharQueueHead(queue));
    printf("tail = %s\n", PCharQueueTail(queue));
    PCharQueueDestroy(queue);
}


int main(int argc, char** argv) {
    IntVectorTest();
    IntSetTest();
    PCharSetTest();
    PCharSetTest2();
    PChar2IntMapTest();
    BoxSetTest();
    BoxVectorTest();
    BoxListTest();
    Box2BoxMapTest();
    PChar2IntVectorMapTest();
    PCharQueueTest();
    return 0;
}
