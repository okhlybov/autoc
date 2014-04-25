require "autoc/collection"


module AutoC
  
  
=begin

== Vector interface

=== Basic operation

  - *_void_* ~type~Ctor(*_Type_* * +self+, *_size_t_* +size+)

  - *_void_* ~type~Copy(*_Type_* * +dst+, *_Type_* * +src+)

  - *_void_* ~type~Dtor(*_Type_* * +self+)

  - *_int_* ~type~Equal(*_Type_* * +lt+, *_Type_* * +rt+)

  - *_E_* ~type~Get(*_Type_* * +self+, *_size_t_* +index+)

  - *_void_* ~type~Resize(*_Type_* * +self+, *_size_t_* +size+)

  - *_void_* ~type~Set(*_Type_* * +self+, *_size_t_* +index+, *_E_* +value+)

  - *_size_t_* ~type~Size(*_Type_* * +self+)

  - *_void_* ~type~Sort(*_Type_* * +self+)

  - *_int_* ~type~Within(*_Type_* * +self+, *_size_t_* +index+)

=== Iteration

  - *_void_* ~type~ItCtor(*_IteratorType_* * +it+, *_Type_* * +self+)

  - *_void_* ~type~ItHasNext(*_IteratorType_* * +it+)

  - *_E_* ~type~ItNext(*_IteratorType_* * +it+)

=end
class Vector < Collection

  def ctor(*args)
    args.empty? ? super() : raise("#{self.class} provides no default constructor")
  end
  
  def write_exported_types(stream)
    stream << %$
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{element.type}* values;
        size_t element_count;
      };
      struct #{it} {
        #{type}* vector;
        size_t index;
      };
    $
  end
  
  def write_exported_declarations(stream, declare, define)
    stream << %$
      #{declare} void #{ctor}(#{type}*, size_t);
      #{declare} void #{dtor}(#{type}*);
      #{declare} void #{copy}(#{type}*, #{type}*);
      #{declare} int #{equal}(#{type}*, #{type}*);
      #{declare} void #{resize}(#{type}*, size_t);
      #{declare} void #{itCtor}(#{it}*, #{type}*);
      #{declare} int #{itHasNext}(#{it}*);
      #{declare} #{element.type} #{itNext}(#{it}*);
      #{define} size_t #{size}(#{type}* self) {
        #{assert}(self);
        return self->element_count;
      }
      #{define} int #{within}(#{type}* self, size_t index) {
        #{assert}(self);
        return index < #{size}(self);
      }
      #{define} #{element.type} #{get}(#{type}* self, size_t index) {
        #{element.type} result;
        #{assert}(self);
        #{assert}(#{within}(self, index));
        #{element.copy("result", "self->values[index]")};
        return result;
      }
      #{define} void #{set}(#{type}* self, size_t index, #{element.type} value) {
        #{assert}(self);
        #{assert}(#{within}(self, index));
        #{element.dtor("self->values[index]")};
        #{element.copy("self->values[index]", "value")};
      }
      #{declare} void #{sort}(#{type}*);
    $
  end
  
  def write_implementations(stream, define)
    stream << %$
      static void #{allocate}(#{type}* self, size_t element_count) {
        #{assert}(self);
        #{assert}(element_count > 0);
        self->element_count = element_count;
        self->values = (#{element.type}*)#{malloc}(element_count*sizeof(#{element.type})); #{assert}(self->values);
      }
      #{define} void #{ctor}(#{type}* self, size_t element_count) {
        size_t index;
        #{assert}(self);
        #{allocate}(self, element_count);
        for(index = 0; index < #{size}(self); ++index) {
          #{element.ctor("self->values[index]")};
        }
      }
      #{define} void #{dtor}(#{type}* self) {
        size_t index;
        #{assert}(self);
        for(index = 0; index < #{size}(self); ++index) {
          #{element.dtor("self->values[index]")};
        }
        #{free}(self->values);
      }
      #{define} void #{copy}(#{type}* dst, #{type}* src) {
        size_t index, size;
        #{assert}(src);
        #{assert}(dst);
        #{allocate}(dst, size = #{size}(src));
        for(index = 0; index < size; ++index) {
          #{element.copy("dst->values[index]", "src->values[index]")};
        }
      }
      #{define} int #{equal}(#{type}* lt, #{type}* rt) {
        size_t index, size;
        #{assert}(lt);
        #{assert}(rt);
        if(#{size}(lt) == (size = #{size}(rt))) {
          for(index = 0; index < size; ++index) {
            if(!#{element.equal("lt->values[index]", "rt->values[index]")}) return 0;
          }
          return 1;
        } else
          return 0;
      }
      #{define} void #{resize}(#{type}* self, size_t element_count) {
        size_t index;
        #{assert}(self);
        if(#{size}(self) != element_count) {
          size_t count;
          #{element.type}* values = (#{element.type}*)#{malloc}(element_count*sizeof(#{element.type})); #{assert}(values);
          if(#{size}(self) > element_count) {
            for(index = element_count; index < #{size}(self); ++index) {
              #{element.dtor("self->values[index]")};
            }
            count = element_count;
          } else {
            for(index = element_count; index < #{size}(self); ++index) {
              #{element.ctor("self->values[index]")};
            }
            count = #{size}(self);
          }
          for(index = 0; index < count; ++index) {
            values[index] = self->values[index];
          }
          #{free}(self->values);
          self->element_count = element_count;
          self->values = values;
        }
      }
      #{define} void #{itCtor}(#{it}* self, #{type}* vector) {
        #{assert}(self);
        #{assert}(vector);
        self->vector = vector;
        self->index = 0;
      }
      #{define} int #{itHasNext}(#{it}* self) {
        #{assert}(self);
        return self->index < #{size}(self->vector);
      }
      #{define} #{element.type} #{itNext}(#{it}* self) {
        #{assert}(self);
        return #{get}(self->vector, self->index++);
      }
      static int #{comparator}(void* lp_, void* rp_) {
        #{element.type}* lp = (#{element.type}*)lp_;
        #{element.type}* rp = (#{element.type}*)rp_;
        if(#{element.equal("*lp", "*rp")}) {
          return 0;
        } else if(#{element.less("*lp", "*rp")}) {
          return -1;
        } else {
          return +1;
        }
      }
      #{define} void #{sort}(#{type}* self) {
        typedef int (*F)(const void*, const void*);
        #{assert}(self);
        qsort(self->values, #{size}(self), sizeof(#{element.type}), (F)#{comparator});
      }
    $
  end
  
end # Vector


end # AutoC