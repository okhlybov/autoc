#ifndef test_h
#define test_h


typedef struct ValueType ValueType;


struct ValueType {
  int value;
  void* block;
};


void ValueTypeCtorEx(ValueType*, int);


#define ValueTypeCtor(obj) ValueTypeCtorRef(&obj)
void ValueTypeCtorRef(ValueType*);


#define ValueTypeDtor(obj) ValueTypeDtorRef(&obj)
void ValueTypeDtorRef(ValueType*);


#define ValueTypeCopy(dst, src) ValueTypeCopyRef(&dst, &src)
void ValueTypeCopyRef(ValueType*, ValueType*);


#define ValueTypeEqual(lt, rt) ValueTypeEqualRef(&lt, &rt)
int ValueTypeEqualRef(ValueType*, ValueType*);


#define ValueTypeLess(lt, rt) ValueTypeLessRef(&lt, &rt)
int ValueTypeLessRef(ValueType*, ValueType*);


#define ValueTypeIdentify(obj) ValueTypeIdentifyRef(&obj)
size_t ValueTypeIdentifyRef(ValueType*);


#endif
