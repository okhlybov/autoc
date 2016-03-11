require "autoc"


Value = Class.new(AutoC::UserDefinedType) do
  def write_intf(stream)
    super
    stream << %~
      typedef struct {
        int* value;
      } Value;
      #define ValueCtor(self) _ValueCtor(&self)
      #define ValueCtorEx(self, v) _ValueCtorEx(&self, v)
      #define ValueDtor(self) _ValueDtor(&self)
      #define ValueCopy(dst, src) _ValueCopy(&dst, &src)
      #define ValueEqual(lt, rt) _ValueEqual(&lt, &rt)
      #define ValueLess(lt, rt) _ValueLess(&lt, &rt)
      #define ValueIdentify(self) _ValueIdentify(&self)
      #define ValueGet(self) *(self).value
      #define ValueSet(self, x) *(self).value = (x)
      void _ValueCtor(Value*);
      void _ValueCtorEx(Value*, int);
      void _ValueDtor(Value*);
      void _ValueCopy(Value*, Value*);
      int _ValueEqual(Value*, Value*);
      int _ValueLess(Value*, Value*);
      size_t _ValueIdentify(Value*);
    ~
  end
  def write_defs(stream)
    super
    stream << %~
      void _ValueCtor(Value* self) {
        #{assert}(self);
        self->value = #{calloc}(1, sizeof(int)); #{assert}(self->value);
      }
      void _ValueCtorEx(Value* self, int value) {
        #{assert}(self);
        ValueCtor(*self);
        *self->value = value;
      }
      void _ValueDtor(Value* self) {
        #{assert}(self);
        #{free}(self->value);
      }
      void _ValueCopy(Value* dst, Value* src) {
        #{assert}(src);
        #{assert}(dst);
        #{assert}(src->value);
        ValueCtorEx(*dst, *src->value);
      }
      int _ValueEqual(Value* lt, Value* rt) {
        #{assert}(lt);
        #{assert}(rt);
        #{assert}(lt->value);
        #{assert}(rt->value);
        return *lt->value == *rt->value;
      }
      int _ValueLess(Value* lt, Value* rt) {
        #{assert}(lt);
        #{assert}(rt);
      #{assert}(lt->value);
      #{assert}(rt->value);
        return *lt->value < *rt->value;
      }
      size_t _ValueIdentify(Value* self) {
        #{assert}(self);
        #{assert}(self->value);
        return *self->value ^ 0xAAAA;
      }
    ~
  end
end.new(
  :type => :Value,
  :ctor => :ValueCtor,
  :dtor => :ValueDtor,
  :copy => :ValueCopy,
  :equal => :ValueEqual,
  :less => :ValueLess,
  :identify => :ValueIdentify
)