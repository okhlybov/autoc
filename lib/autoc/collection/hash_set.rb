require "autoc/collection"
require "autoc/collection/list"


require "autoc/collection/set"
require "autoc/collection/iterator"


module AutoC

  
=begin

HashSet< *_E_* > is a hash-based unordered container holding unique elements.

The collection's C++ counterpart is +std::unordered_set<>+ template class.

== Generated C interface

=== Collection management

[cols=2*]
|===
|*_void_* ~type~Copy(*_Type_* * +dst+, *_Type_* * +src+)
|
Create a new set +dst+ filled with the contents of +src+.
A copy operation is performed on every element in +src+.

NOTE: Previous contents of +dst+ is overwritten.

|*_void_* ~type~Ctor(*_Type_* * +self+)
|
Create a new empty set +self+.

NOTE: Previous contents of +self+ is overwritten.

|*_void_* ~type~Dtor(*_Type_* * +self+)
|
Destroy set +self+.
Stored elements are destroyed as well by calling the respective destructors.

|*_int_* ~type~Equal(*_Type_* * +lt+, *_Type_* * +rt+)
|
Return non-zero value if sets +lt+ and +rt+ are considered equal by contents and zero value otherwise.

|*_size_t_* ~type~Identify(*_Type_* * +self+)
|
Return hash code for set +self+.
|===

=== Basic operations

[cols=2*]
|===
|*_int_* ~type~Contains(*_Type_* * +self+, *_E_* +what+)
|
Return non-zero value if set +self+ contains an element considered equal to the element +what+ and zero value otherwise.

|*_int_* ~type~Empty(*_Type_* * +self+)
|
Return non-zero value if set +self+ contains no elements and zero value otherwise.

|*_E_* ~type~Get(*_Type_* * +self+, *_E_* +what+)
|
Return a _copy_ of the element in +self+ considered equal to the element +what+.

WARNING: +self+ *must* contain such element otherwise the behavior is undefined. See ~type~Contains().

|*_void_* ~type~Purge(*_Type_* * +self+)
|
Remove and destroy all elements stored in +self+.

|*_int_* ~type~Put(*_Type_* * +self+, *_E_* +what+)
|
Put a _copy_ of the element +what+ into +self+ *only if* there is no such element in +self+ which is considered equal to +what+.

Return non-zero value on successful element put (that is there was not such element in +self+) and zero value otherwise.

|*_int_* ~type~Replace(*_Type_* * +self+, *_E_* +with+)
|
If +self+ contains an element which is considered equal to the element +with+,
replace that element with a _copy_ of +with+, otherwise do nothing.
Replaced element is destroyed.

Return non-zero value if the replacement was actually performed and zero value otherwise.

|*_int_* ~type~Remove(*_Type_* * +self+, *_E_* +what+)
|
Remove and destroy an element in +self+ which is considered equal to the element +what+.

Return non-zero value on successful element removal and zero value otherwise.

|*_size_t_* ~type~Size(*_Type_* * +self+)
|
Return number of elements stored in +self+.
|===

=== Logical operations

[cols=2*]
|===
|*_void_* ~type~Exclude(*_Type_* * +self+, *_Type_* * +other+)
|
Perform the difference operation that is +self+ will retain only the elements not contained in +other+.

Removed elements are destroyed.
|*_void_* ~type~Include(*_Type_* * +self+, *_Type_* * +other+)
|
Perform the union operation that is +self+ will contain the elements from both +self+ and +other+.

+self+ receives the _copies_ of extra elements in +other+.

|*_void_* ~type~Invert(*_Type_* * +self+, *_Type_* * +other+)
|
Perform the symmetric difference operation that is +self+ will retain the elements contained in either +self+ or +other+, but not in both.

Removed elements are destroyed, extra elements are _copied_.

|*_void_* ~type~Retain(*_Type_* * +self+, *_Type_* * +other+)
|
Perform the intersection operation that is +self+ will retain only the elements contained in both +self+ and +other+.

Removed elements are destroyed.
|===

=== Iteration

[cols=2*]
|===
|*_void_* ~it~Ctor(*_IteratorType_* * +it+, *_Type_* * +self+)
|
Create a new iterator +it+ on set +self+.

NOTE: As the set is an unordered sequence, the traversal order is unspecified.

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
class HashSet < Collection

  include Sets
  include Iterators::Unidirectional

  def initialize(*args)
    super
    @list = List.new(list, element, :static)
    key_requirement(element)
  end
  
  def write_intf_decls(stream, declare, define)
    super
  end

  def write_intf_types(stream)
    super
    @list.write_intf_types(stream)
    stream << %$
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{@list.type_ref} buckets;
        size_t bucket_count, min_bucket_count;
        size_t size, min_size, max_size;
        unsigned min_fill, max_fill, capacity_multiplier; /* ?*1e-2 */
      };
      struct #{it} {
        #{type_ref} set;
        size_t bucket_index;
        #{@list.it} it;
      };
    $
  end
  
  def write_impls(stream, define)
    @list.write_intf_decls(stream, static, inline)
    @list.write_impls(stream, static)
    super
    stream << %$
      static void #{rehash}(#{type_ref} self) {
        #{@list.type_ref} buckets;
        size_t index, bucket_count, size, fill;
        #{assert}(self);
        #{assert}(self->min_fill > 0);
        #{assert}(self->max_fill > 0);
        #{assert}(self->min_fill < self->max_fill);
        #{assert}(self->min_bucket_count > 0);
        if(self->buckets) {
          if(self->min_size < self->size && self->size < self->max_size) return;
          fill = (size_t)((float)self->size/self->bucket_count*100);
          if(fill > self->max_fill) {
            bucket_count = (size_t)((float)self->bucket_count/100*self->capacity_multiplier);
          } else
          if(fill < self->min_fill && self->bucket_count > self->min_bucket_count) {
            bucket_count = (size_t)((float)self->bucket_count/self->capacity_multiplier*100);
            if(bucket_count < self->min_bucket_count) bucket_count = self->min_bucket_count;
          } else
            return;
          size = self->size;
          self->min_size = (size_t)((float)self->min_fill/100*size);
          self->max_size = (size_t)((float)self->max_fill/100*size);
        } else {
          bucket_count = self->min_bucket_count;
          size = 0;
        }
        buckets = (#{@list.type_ref})#{malloc}(bucket_count*sizeof(#{@list.type})); #{assert}(buckets);
        for(index = 0; index < bucket_count; ++index) {
          #{@list.ctor}(&buckets[index]);
        }
        if(self->buckets) {
          #{it} it;
          #{itCtor}(&it, self);
          while(#{itMove}(&it)) {
            #{@list.type}* bucket;
            #{element.type} element = #{itGet}(&it);
            bucket = &buckets[#{element.identify("element")} % bucket_count];
            #{@list.push}(bucket, element);
            #{element.dtor("element")};
          }
          #{dtor}(self);
        }
        self->buckets = buckets;
        self->bucket_count = bucket_count;
        self->size = size;
      }
      #{define} #{ctor.definition} {
        #{assert}(self);
        self->min_bucket_count = 16;
        self->min_fill = 20;
        self->max_fill = 80;
        self->min_size = (size_t)((float)self->min_fill/100*self->min_bucket_count);
        self->max_size = (size_t)((float)self->max_fill/100*self->min_bucket_count);
        self->capacity_multiplier = 200;
        self->buckets = NULL;
        #{rehash}(self);
      }
      #{define} #{dtor.definition} {
        size_t i;
        #{assert}(self);
        for(i = 0; i < self->bucket_count; ++i) {
          #{@list.dtor}(&self->buckets[i]);
        }
        #{free}(self->buckets);
      }
      #{define} void #{purge}(#{type_ref} self) {
        #{assert}(self);
        #{dtor}(self);
        self->buckets = NULL;
        #{rehash}(self);
      }
      #{define} int #{contains}(#{type_ref} self, #{element.type} element) {
        #{assert}(self);
        return #{@list.contains}(&self->buckets[#{element.identify("element")} % self->bucket_count], element);
      }
      #{define} #{element.type} #{get}(#{type_ref} self, #{element.type} element) {
        #{element.type} result;
        #{assert}(self);
        #{assert}(#{contains}(self, element));
        result = #{@list.find}(&self->buckets[#{element.identify("element")} % self->bucket_count], element);
        return result;
      }
      #{define} int #{put}(#{type_ref} self, #{element.type} element) {
        #{@list.type_ref} bucket;
        #{assert}(self);
        bucket = &self->buckets[#{element.identify("element")} % self->bucket_count];
        if(!#{@list.contains}(bucket, element)) {
          #{@list.push}(bucket, element);
          ++self->size;
          #{rehash}(self);
          return 1;
        }
        return 0;
      }
      #{define} int #{replace}(#{type_ref} self, #{element.type} element) {
        #{@list.type_ref} bucket;
        #{assert}(self);
        bucket = &self->buckets[#{element.identify("element")} % self->bucket_count];
        return #{@list.replace}(bucket, element);
      }
      #{define} int #{remove}(#{type_ref} self, #{element.type} element) {
        #{@list.type_ref} bucket;
        #{assert}(self);
        bucket = &self->buckets[#{element.identify("element")} % self->bucket_count];
        if(#{@list.remove}(bucket, element)) {
          --self->size;
          #{rehash}(self);
          return 1;
        }
        return 0;
      }
      #{define} void #{itCtor}(#{it_ref} self, #{type_ref} set) {
        #{assert}(self);
        self->set = set;
        self->bucket_index = self->set->bucket_count;
      }
      #{define} int #{itMove}(#{it_ref} self) {
        #{assert}(self);
        if(self->bucket_index >= self->set->bucket_count) #{@list.itCtor}(&self->it, &self->set->buckets[self->bucket_index = 0]);
        if(#{@list.itMove}(&self->it)) return 1;
        while(++self->bucket_index < self->set->bucket_count) {
          #{@list.itCtor}(&self->it, &self->set->buckets[self->bucket_index]);
          if(#{@list.itMove}(&self->it)) return 1;
        }
        return 0;
      }
      #{define} #{element.type} #{itGet}(#{it_ref} self) {
        #{assert}(self);
        return #{@list.itGet}(&self->it);
      }
      static #{element.type_ref} #{itGetRef}(#{it_ref} self) {
        #{assert}(self);
        return #{@list.itGetRef}(&self->it);
      }
    $
  end
  
  private
  
  def key_requirement(obj)
    element_requirement(obj)
    raise "type #{obj.type} (#{obj}) must be hashable" unless obj.hashable?
  end

end # HashSet


end # AutoC