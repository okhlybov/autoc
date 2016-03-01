require "autoc/collection"


module AutoC
  
  
=begin

Vector is an ordered random access sequence container.

The collection's C++ counterpart is +std::vector<>+ template class.

== Generated C interface

=== Collection management

[cols="2*"]
|===
|*_void_* ~type~Copy(*_Type_* * +dst+, *_Type_* * +src+)
|
Create a new vector +dst+ filled with the contents of +src+.
A copy operation is performed on every element in +src+.

NOTE: Previous contents of +dst+ is overwritten.

|*_void_* ~type~Ctor(*_Type_* * +self+, *_size_t_* +size+)
|
Create a new vector +self+ of size +size+.
The elements are initialized with either supplied or generated default parameterless constructor.

WARNING: +size+ must be greater than zero.

NOTE: Previous contents of +self+ is overwritten.

|*_void_* ~type~Dtor(*_Type_* * +self+)
|
Destroy vector +self+.
Stored elements are destroyed as well by calling the respective destructors.

|*_int_* ~type~Equal(*_Type_* * +lt+, *_Type_* * +rt+)
|
Return non-zero value if vectors +lt+ and +rt+ are considered equal by contents and zero value otherwise.

|*_size_t_* ~type~Identify(*_Type_* * +self+)
|
Return hash code for vector +self+.
|===

=== Basic operations

[cols=2*]
|===
|*_E_* ~type~Get(*_Type_* * +self+, *_size_t_* +index+)
|
Return a _copy_ of the element stored in +self+ at position +index+.

WARNING: +index+ *must* be a valid index otherwise the behavior is undefined. See ~type~Within().

|*_void_* ~type~Resize(*_Type_* * +self+, *_size_t_* +size+)
|
Set new size of vector +self+ to +size+.

If new size is greater than the old one, extra elements are created with default parameterless constructors.
If new size is smaller the the old one, excessive elements are destroyed.

WARNING: +size+ *must* be greater than zero.

|*_void_* ~type~Set(*_Type_* * +self+, *_size_t_* +index+, *_E_* +what+)
|

Store a _copy_ of the element +what+ in vector +self+ at position +index+ destroying previous contents.

WARNING: +index+ *must* be a valid index otherwise the behavior is undefined. See ~type~Within().

|*_size_t_* ~type~Size(*_Type_* * +self+)
|
Return number of elements stored in vector +self+.

|*_void_* ~type~Sort(*_Type_* * +self+)
|
Perform an ascending sort.
See ~type~SortEx().

NOTE : optional operation.

|*_void_* ~type~SortEx(*_Type_* * +self+, *_int_* ascending)
|
NOTE : optional operation.

Perform a sort operation on the contents of vector +self+ utilizing either generated of user supplied ordering functions.
If the +ascending+ is non-zero, perform the sorting in ascending order otherwise perform the soring in descending order.

Note that this operation is defined only if element type is orderable, e.g. has equality testing and comparison operations defined.

|*_int_* ~type~Within(*_Type_* * +self+, *_size_t_* +index+)
|
Return non-zero value if +index+ is a valid index and zero value otherwise.
Valid index belongs to the range 0 ... ~type~Size()-1.
|===

=== Iteration

[cols=2*]
|===
|*_void_* ~it~Ctor(*_IteratorType_* * +it+, *_Type_* * +self+)
|
Create a new forward iterator +it+ on vector +self+.

NOTE: Previous contents of +it+ is overwritten.

|*_void_* ~it~CtorEx(*_IteratorType_* * +it+, *_Type_* * +self+, *_int_* +forward+)
|
Create a new iterator +it+ on vector +self+.
Non-zero value of +forward+ specifies a forward iterator, zero value specifies a backward iterator.

NOTE: Previous contents of +it+ is overwritten.

|*_int_* ~it~Move(*_IteratorType_* * +it+)
|
Advance iterator position of +it+ *and* return non-zero value if new position is valid and zero value otherwise.

|*_E_* ~it~Get(*_IteratorType_* * +it+)
|
Return a _copy_ of current element pointed to by the iterator +it+.

WARNING: current position *must* be valid otherwise the behavior is undefined. See ~it~Move().
|===

=end
class Vector < Collection

  def initialize(*args)
    super
    # Override the default type constructor as the Vector's requires one extra parameter
    # Note that this makes the Vector instance non-constructible
    @ctor = define_redirector(:ctor, Function::Signature.new([type_ref^:self, :size_t^:element_count]))
  end

  # No default constructor provided
  def constructible?; false end
    
  def write_intf_types(stream)
    super
    stream << %$
      /***
      **** #{type}<#{element.type}> (#{self.class})
      ***/
    $ if public?
    stream << %$
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{element.type_ref} values;
        size_t element_count;
      };
      struct #{it} {
        #{type_ref} vector;
        int index, forward;
      };
    $
  end
  
  def write_intf_decls(stream, declare, define)
    super
    stream << %$
      #{declare} #{ctor.declaration};
      #{declare} #{dtor.declaration};
      #{declare} #{copy.declaration};
      /* TODO #{copyRange}() */
      #{declare} #{equal.declaration};
      #{declare} #{identify.declaration};
      #{declare} void #{resize}(#{type_ref}, size_t);
      #{define} size_t #{size}(#{type_ref} self) {
        #{assert}(self);
        return self->element_count;
      }
      #{define} int #{within}(#{type_ref} self, size_t index) {
        #{assert}(self);
        return index < #{size}(self);
      }
      #{define} #{element.type} #{get}(#{type_ref} self, size_t index) {
        #{element.type} result;
        #{assert}(self);
        #{assert}(#{within}(self, index));
        #{element.copy("result", "self->values[index]")};
        return result;
      }
      #{define} void #{set}(#{type_ref} self, size_t index, #{element.type} value) {
        #{assert}(self);
        #{assert}(#{within}(self, index));
        #{element.dtor("self->values[index]")};
        #{element.copy("self->values[index]", "value")};
      }
      #define #{itCtor}(self, type) #{itCtorEx}(self, type, 1)
      #{define} void #{itCtorEx}(#{it_ref} self, #{type_ref} vector, int forward) {
        #{assert}(self);
        #{assert}(vector);
        self->vector = vector;
        self->forward = forward;
        self->index = forward ? -1 : #{size}(vector);
      }
      #{define} int #{itMove}(#{it_ref} self) {
        #{assert}(self);
        if(self->forward) ++self->index; else --self->index;
        return #{within}(self->vector, self->index);
      }
      #{define} #{element.type} #{itGet}(#{it_ref} self) {
        #{element.type} e;
        #{assert}(self);
        e = #{get}(self->vector, self->index); return e;
        /* OrangeC 5.60.??? compiler strangely fails to compile the direct return statement without using the intermediate variable */
      }
    $
    stream << %$
      #define #{sort}(self) #{sortEx}(self, 1)
      #{declare} void #{sortEx}(#{type_ref}, int);
    $ if element.orderable?
  end
  
  def write_impls(stream, define)
    super
    stream << %$
      static void #{allocate}(#{type_ref} self, size_t element_count) {
        #{assert}(self);
        #{assert}(element_count > 0);
        self->element_count = element_count;
        self->values = (#{element.type}*)#{malloc}(element_count*sizeof(#{element.type})); #{assert}(self->values);
      }
      #{define} #{ctor.definition} {
        size_t index;
        #{assert}(self);
        #{allocate}(self, element_count);
        for(index = 0; index < #{size}(self); ++index) {
          #{element.ctor("self->values[index]")};
        }
      }
      #{define} #{dtor.definition} {
        size_t index;
        #{assert}(self);
        for(index = 0; index < #{size}(self); ++index) {
          #{element.dtor("self->values[index]")};
        }
        #{free}(self->values);
      }
      #{define} #{copy.definition} {
        size_t index, size;
        #{assert}(src);
        #{assert}(dst);
        #{allocate}(dst, size = #{size}(src));
        for(index = 0; index < size; ++index) {
          #{element.copy("dst->values[index]", "src->values[index]")};
        }
      }
      #{define} #{equal.definition} {
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
      #{define} #{identify.definition} {
        size_t index, result = 0;
        #{assert}(self);
        for(index = 0; index < self->element_count; ++index) {
          result ^= #{element.identify("self->values[index]")};
          result = AUTOC_RCYCLE(result);
        }
        return result;
      }
      #{define} void #{resize}(#{type_ref} self, size_t new_element_count) {
        size_t index, element_count, from, to;
        #{assert}(self);
        if((element_count = #{size}(self)) != new_element_count) {
          #{element.type_ref} values = (#{element.type_ref})#{malloc}(new_element_count*sizeof(#{element.type})); #{assert}(values);
          from = AUTOC_MIN(element_count, new_element_count);
          to = AUTOC_MAX(element_count, new_element_count);
          for(index = 0; index < from; ++index) {
            values[index] = self->values[index];
          }
          if(element_count > new_element_count) {
            for(index = from; index < to; ++index) {
              #{element.dtor("self->values[index]")};
            }
          } else {
            for(index = from; index < to; ++index) {
              #{element.ctor("values[index]")};
            }
          }
          #{free}(self->values);
          self->values = values;
          self->element_count = new_element_count;
        }
      }
    $
    stream << %$
      static int #{ascend}(void* lp_, void* rp_) {
        #{element.type_ref} lp = (#{element.type_ref})lp_;
        #{element.type_ref} rp = (#{element.type_ref})rp_;
        if(#{element.equal("*lp", "*rp")}) {
          return 0;
        } else if(#{element.less("*lp", "*rp")}) {
          return -1;
        } else {
          return +1;
        }
      }
      static int #{descend}(void* lp_, void* rp_) {
        return -#{ascend}(lp_, rp_);
      }
      #{define} void #{sortEx}(#{type_ref} self, int ascending) {
        typedef int (*F)(const void*, const void*);
        #{assert}(self);
        qsort(self->values, #{size}(self), sizeof(#{element.type}), ascending ? (F)#{ascend} : (F)#{descend});
      }
    $ if element.orderable?
  end
 
  private
  
  def element_requirement(obj)
    # Vector requires the element to have default parameterless constructor
    raise "type #{obj.type} (#{obj}) must be constructible" unless obj.constructible?
    super
  end

end # Vector


end # AutoC