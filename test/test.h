#ifndef test_h
#define test_h


typedef struct ValueType ValueType;


struct ValueType {
  int value;
  void* block;
};


void ValueTypeCtorEx(ValueType*, int);


#define ValueTypeCtor(obj) _ValueTypeCtor(&obj)
void _ValueTypeCtor(ValueType*);


#define ValueTypeDtor(obj) _ValueTypeDtor(&obj)
void _ValueTypeDtor(ValueType*);


#define ValueTypeCopy(dst, src) _ValueTypeCopy(&dst, &src)
void _ValueTypeCopy(ValueType*, ValueType*);


#define ValueTypeEqual(lt, rt) _ValueTypeEqual(&lt, &rt)
int _ValueTypeEqual(ValueType*, ValueType*);


#define ValueTypeLess(lt, rt) _ValueTypeLess(&lt, &rt)
int _ValueTypeLess(ValueType*, ValueType*);


#define ValueTypeIdentify(obj) _ValueTypeIdentify(&obj)
size_t _ValueTypeIdentify(ValueType*);


#endif
