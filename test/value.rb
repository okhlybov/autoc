require 'autoc/type'

Value = AutoC::Synthetic.new :Value, interface: %$
    #include <malloc.h>
    /**
     * @public @defgroup Value Value :: a generic full fledged value type
     * @{
     */
    typedef struct {
      int* value;
    } Value;
    #define ValueGet(v) (*(v).value)
    #define ValueSetup_(v, x) ValueSetup(&v, x)
    static void ValueSetup(Value* self, int value) {
      self->value = malloc(sizeof(int));
      *self->value = value;
    }
    #define ValueCreate_(v) ValueCreate(&v)
    static void ValueCreate(Value* self) {
      ValueSetup(self, 0);
    }
    #define ValueDestroy_(v) ValueDestroy(&v)
    static void ValueDestroy(Value* self) {
      free(self->value);
    }
    #define ValueCopy_(v, s) ValueCopy(&v, &s)
    static void ValueCopy(Value* self, const Value* source) {
      ValueSetup(self, ValueGet(*source));
    }
    #define ValueEqual_(lt, rt) ValueEqual(&lt, &rt)
    static int ValueEqual(const Value* lt, const Value* rt) {
      return ValueGet(*lt) == ValueGet(*rt);
    }
    #define ValueCode_(v) ValueCode(&v)
    static size_t ValueCode(const Value* self) {
      return ValueGet(*self);
    }
    #define ValueCompare_(lt, rt) ValueCompare(&lt, &rt);
    static int ValueCompare(const Value* lt, const Value* rt) {
      if(ValueGet(*lt) > ValueGet(*rt)) return +1;
      else if(ValueGet(*lt) < ValueGet(*rt)) return -1;
      else return 0;
    }
    /** @} */
  $,
  default_create: :ValueCreate_,
  custom_create: AutoC::Function.new(:ValueSetup_, [:Value, :int]),
  destroy: :ValueDestroy_,
  copy: :ValueCopy_,
  equal: :ValueEqual_,
  compare: :ValueCompare_,
  code: :ValueCode_
