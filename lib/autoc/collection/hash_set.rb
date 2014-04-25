require "autoc/collection"
require "autoc/collection/list"


module AutoC

  
=begin

== Generated C interface

=== Collection management

- *_void_* ~type~Copy(*_Type_* * +dst+, *_Type_* * +src+)

- *_void_* ~type~Ctor(*_Type_* * +self+)

- *_void_* ~type~Dtor(*_Type_* * +self+)

- *_int_* ~type~Equal(*_Type_* * +lt+, *_Type_* * +rt+)

=== Basic operations

- *_int_* ~type~Contains(*_Type_* * +self+, *_E_* +value+)

- *_int_* ~type~Empty(*_Type_* * +self+)

- *_E_* ~type~Get(*_Type_* * +self+)

- *_void_* ~type~Purge(*_Type_* * +self+)

- *_void_* ~type~Put(*_Type_* * +self+, *_E_* +value+)

- *_void_* ~type~Rehash(*_Type_* * +self+)

- *_int_* ~type~Replace(*_Type_* * +self+, *_E_* +what+, *_E_* +with+)

- *_int_* ~type~Remove(*_Type_* * +self+, *_E_* +value+)

- *_size_t_* ~type~Size(*_Type_* * +self+)

=== Logical operations

- *_void_* ~type~Not(*_Type_* * +self+, *_Type_* * +other+)

- *_void_* ~type~And(*_Type_* * +self+, *_Type_* * +other+)

- *_void_* ~type~Or(*_Type_* * +self+, *_Type_* * +other+)

- *_void_* ~type~Xor(*_Type_* * +self+, *_Type_* * +other+)

=== Iteration

- *_void_* ~type~ItCtor(*_IteratorType_* * +it+, *_Type_* * +self+)

- *_void_* ~type~ItHasNext(*_IteratorType_* * +it+)

- *_E_* ~type~ItNext(*_IteratorType_* * +it+)

=end
class HashSet < Collection

  def initialize(*args)
    super
    @list = List.new(list, element, :static)
  end
  
  def write_exported_types(stream)
    @list.write_exported_types(stream)
    stream << %$
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{@list.type}* buckets;
        size_t bucket_count, min_bucket_count;
        size_t size, min_size, max_size;
        unsigned min_fill, max_fill, capacity_multiplier; /* ?*1e-2 */
      };
      struct #{it} {
        #{type}* set;
        int bucket_index;
        #{@list.it} it;
      };
    $
  end
  
  def write_exported_declarations(stream, declare, define)
    stream << %$
      #{declare} void #{ctor}(#{type}*);
      #{declare} void #{dtor}(#{type}*);
      #{declare} void #{copy}(#{type}*, #{type}*);
      #{declare} int #{equal}(#{type}*, #{type}*);
      #{declare} void #{purge}(#{type}*);
      #{declare} void #{rehash}(#{type}*);
      #{declare} int #{contains}(#{type}*, #{element.type});
      #{declare} #{element.type} #{get}(#{type}*, #{element.type});
      #{declare} size_t #{size}(#{type}*);
      #{declare} int #{empty}(#{type}*);
      #{declare} int #{put}(#{type}*, #{element.type});
      #{declare} int #{replace}(#{type}*, #{element.type}, #{element.type});
      #{declare} int #{remove}(#{type}*, #{element.type});
      #{declare} void #{not!}(#{type}*, #{type}*);
      #{declare} void #{and!}(#{type}*, #{type}*);
      #{declare} void #{or!}(#{type}*, #{type}*);
      #{declare} void #{xor!}(#{type}*, #{type}*);
      #{declare} void #{itCtor}(#{it}*, #{type}*);
      #{declare} int #{itHasNext}(#{it}*);
      #{declare} #{element.type} #{itNext}(#{it}*);
    $
  end

  def write_implementations(stream, define)
    @list.write_exported_declarations(stream, static, inline)
    @list.write_implementations(stream, static)
    stream << %$
      #{define} void #{ctor}(#{type}* self) {
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
      #{define} void #{dtor}(#{type}* self) {
        size_t i;
        #{assert}(self);
        for(i = 0; i < self->bucket_count; ++i) {
          #{@list.dtor}(&self->buckets[i]);
        }
        #{free}(self->buckets);
      }
      #{define} void #{copy}(#{type}* dst, #{type}* src) {
        #{it} it;
        #{assert}(src);
        #{assert}(dst);
        #{ctor}(dst);
        #{itCtor}(&it, src);
        while(#{itHasNext}(&it)) {
          #{element.type} element;
          #{put}(dst, element = #{itNext}(&it));
          #{element.dtor("element")};
        }
      }
      static int #{containsAllOf}(#{type}* self, #{type}* other) {
        #{it} it;
        #{itCtor}(&it, self);
        while(#{itHasNext}(&it)) {
          int found = 0;
          #{element.type} element = #{itNext}(&it);
          if(#{contains}(other, element)) found = 1;
          #{element.dtor("element")};
          if(!found) return 0;
        }
        return 1;
      }
      #{define} int #{equal}(#{type}* lt, #{type}* rt) {
        #{assert}(lt);
        #{assert}(rt);
        return #{size}(lt) == #{size}(rt) && #{containsAllOf}(lt, rt) && #{containsAllOf}(rt, lt);
      }
      #{define} void #{purge}(#{type}* self) {
        #{assert}(self);
        #{dtor}(self);
        self->buckets = NULL;
        #{rehash}(self);
      }
      #{define} void #{rehash}(#{type}* self) {
        #{@list.type}* buckets;
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
        buckets = (#{@list.type}*)#{malloc}(bucket_count*sizeof(#{@list.type})); #{assert}(buckets);
        for(index = 0; index < bucket_count; ++index) {
          #{@list.ctor}(&buckets[index]);
        }
        if(self->buckets) {
          #{it} it;
          #{itCtor}(&it, self);
          while(#{itHasNext}(&it)) {
            #{@list.type}* bucket;
            #{element.type} element = #{itNext}(&it);
            bucket = &buckets[#{element.identify("element")} % bucket_count];
            #{@list.put}(bucket, element);
            #{element.dtor("element")};
          }
          #{dtor}(self);
        }
        self->buckets = buckets;
        self->bucket_count = bucket_count;
        self->size = size;
      }
      #{define} int #{contains}(#{type}* self, #{element.type} element_) {
        int result;
        #{element.type} element;
        #{assert}(self);
        #{element.copy("element", "element_")};
        result = #{@list.contains}(&self->buckets[#{element.identify("element")} % self->bucket_count], element);
        #{element.dtor("element")};
        return result;
      }
      #{define} #{element.type} #{get}(#{type}* self, #{element.type} element_) {
        #{element.type} result;
        #{element.type} element;
        #{assert}(self);
        #{element.copy("element", "element_")};
        #{assert}(#{contains}(self, element));
        result = #{@list.find}(&self->buckets[#{element.identify("element")} % self->bucket_count], element);
        #{element.dtor("element")};
        return result;
      }
      #{define} size_t #{size}(#{type}* self) {
        #{assert}(self);
        return self->size;
      }
      #{define} int #{empty}(#{type}* self) {
        #{assert}(self);
        return !self->size;
      }
      #{define} int #{put}(#{type}* self, #{element.type} element_) {
        #{element.type} element;
        #{@list.type}* bucket;
        int contained = 1;
        #{assert}(self);
        #{element.copy("element", "element_")};
        bucket = &self->buckets[#{element.identify("element")} % self->bucket_count];
        if(!#{@list.contains}(bucket, element)) {
          #{@list.put}(bucket, element);
          ++self->size;
          contained = 0;
          #{rehash}(self);
        }
        #{element.dtor("element")};
        return contained;
      }
      #{define} int #{replace}(#{type}* self, #{element.type} what_, #{element.type} with_) {
        #{element.type} what, with;
        #{@list.type}* bucket;
        int contained = 1;
        #{assert}(self);
        #{element.copy("what", "what_")};
        #{element.copy("with", "with_")};
        bucket = &self->buckets[#{element.identify("what")} % self->bucket_count];
        if(!#{@list.replace}(bucket, what, with)) {
          #{@list.put}(bucket, with);
          ++self->size;
          contained = 0;
          #{rehash}(self);
        }
        #{element.dtor("what")};
        #{element.dtor("with")};
        return contained;
      }
      #{define} int #{remove}(#{type}* self, #{element.type} element_) {
        #{element.type} element;
        #{@list.type}* bucket;
        int removed = 0;
        #{assert}(self);
        #{element.copy("element", "element_")};
        bucket = &self->buckets[#{element.identify("element")} % self->bucket_count];
        if(#{@list.remove}(bucket, element)) {
          --self->size;
          removed = 1;
          #{rehash}(self);
        }
        #{element.dtor("element")};
        return removed;
      }
      #{define} void #{not!}(#{type}* self, #{type}* other) {
        #{it} it;
        #{assert}(self);
        #{assert}(other);
        #{itCtor}(&it, other);
        while(#{itHasNext}(&it)) {
          #{element.type} element;
          #{remove}(self, element = #{itNext}(&it));
          #{element.dtor("element")};
        }
        #{rehash}(self);
      }
      #{define} void #{or!}(#{type}* self, #{type}* other) {
        #{it} it;
        #{assert}(self);
        #{assert}(other);
        #{itCtor}(&it, other);
        while(#{itHasNext}(&it)) {
          #{element.type} element;
          #{put}(self, element = #{itNext}(&it));
          #{element.dtor("element")};
        }
        #{rehash}(self);
      }
      #{define} void #{and!}(#{type}* self, #{type}* other) {
        #{it} it;
        #{type} set;
        #{assert}(self);
        #{assert}(other);
        #{ctor}(&set);
        #{itCtor}(&it, self);
        while(#{itHasNext}(&it)) {
          #{element.type} element = #{itNext}(&it);
          if(#{contains}(other, element)) #{put}(&set, element);
          #{element.dtor("element")};
        }
        #{itCtor}(&it, other);
        while(#{itHasNext}(&it)) {
          #{element.type} element = #{itNext}(&it);
          if(#{contains}(self, element)) #{put}(&set, element);
          #{element.dtor("element")};
        }
        #{dtor}(self);
        self->buckets = set.buckets;
        self->size = set.size;
        #{rehash}(self);
        /*#{dtor}(&set);*/
      }
      #{define} void #{xor!}(#{type}* self, #{type}* other) {
        #{it} it;
        #{type} set;
        #{assert}(self);
        #{assert}(other);
        #{ctor}(&set);
        #{itCtor}(&it, self);
        while(#{itHasNext}(&it)) {
          #{element.type} element = #{itNext}(&it);
          if(!#{contains}(other, element)) #{put}(&set, element);
          #{element.dtor("element")};
        }
        #{itCtor}(&it, other);
        while(#{itHasNext}(&it)) {
          #{element.type} element = #{itNext}(&it);
          if(!#{contains}(self, element)) #{put}(&set, element);
          #{element.dtor("element")};
        }
        #{dtor}(self);
        self->buckets = set.buckets;
        self->size = set.size;
        #{rehash}(self);
        /*#{dtor}(&set);*/
      }
      #{define} void #{itCtor}(#{it}* self, #{type}* set) {
        #{assert}(self);
        self->set = set;
        self->bucket_index = 0;
        #{@list.itCtor}(&self->it, &set->buckets[0]);
      }
      #{define} int #{itHasNext}(#{it}* self) {
        #{assert}(self);
        if(#{@list.itHasNext}(&self->it)) {
          return 1;
        } else {
          size_t i; for(i = self->bucket_index+1; i < self->set->bucket_count; ++i) {
            if(!#{@list.empty}(&self->set->buckets[i])) {
              return 1;
            }
          }
          return 0;
        }
      }
      #{define} #{element.type} #{itNext}(#{it}* self) {
        #{assert}(self);
        #{assert}(#{itHasNext}(self));
          if(#{@list.itHasNext}(&self->it)) {
            return #{@list.itNext}(&self->it);
          } else {
            size_t i; for(i = self->bucket_index+1; i < self->set->bucket_count; ++i) {
            if(!#{@list.empty}(&self->set->buckets[i])) {
            #{@list.itCtor}(&self->it, &self->set->buckets[i]);
              self->bucket_index = i;
              return #{@list.itNext}(&self->it);
            }
          }
          #{abort}();
        }
      }
    $
  end
  
end # HashSet


end # AutoC