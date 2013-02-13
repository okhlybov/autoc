require 'autoc/code_builder'

##
# Generators for strongly-typed C data containers similar to C++ STL container classes.
#
# The data types used as elements for generated containers may be of almost arbitrary type,
# with either value or reference semantics. A data type may be supplied with a host of user-defined functions
# performing specific operations such as cloning, destruction and a like on it.
# If no such function is specified, a default operation is generated.
module DataStructBuilder


# :nodoc:
PrologueCode = Class.new(CodeBuilder::Code) do
  def write_intf(stream)
    stream << %$
      #include <stddef.h>
      #include <stdlib.h>
      #include <malloc.h>
      #include <assert.h>
      #ifndef __DATA_STRUCT_INLINE
        #ifdef __STDC__
          #define __DATA_STRUCT_INLINE static
        #else
          #define __DATA_STRUCT_INLINE static inline
        #endif
      #endif
    $
  end
end.new # PrologueCode


##
# Base class for all C data container generators.
class Code < CodeBuilder::Code
  undef abort;
  ##
  # String-like prefix for generated data type. Must be a valid C identifier.
  attr_reader :type
  ##
  # Setups the data structure generator.
  # +type+ is a C type name used as a prefix for generated container functions. It must be a valid C identifier.
  def initialize(type)
    @type = type.to_s # TODO validate
    setup_overrides
  end
  protected
  # :nodoc:
  def method_missing(method, *args)
    if @overrides.include?(method)
      @overrides[method]
    else
      s = method.to_s
      @type + s[0].capitalize + s[1..-1]
    end
  end
  # :nodoc:
  def setup_overrides
    @overrides = {:malloc=>'malloc', :calloc=>'calloc', :free=>'free', :assert=>'assert', :abort=>'abort', :inline=>'__DATA_STRUCT_INLINE'}
  end
end # Code


##
# Indicates that the type class including this module provides the assignment operation.
# The user-defined function is assigned to the key +:assign+ and
# is expected to have the signature +type+ _assignment-function_(+type+).
# The C function provided might return its argument or a new copy. It is also responsible for such things like ownership management etc.
# When no user-defined function is specified, this module generates simple value assignment with = operator.
module Assignable
  Methods = [:assign] # :nodoc:
  ##
  # Returns +true+ when used-defined assignment function is specified and +false+ otherwise.
  def assign?
    !properties[:assign].nil?
  end
  ##
  # Returns string representing the C assignment expression for +obj+.
  # +obj+ is a string-like object containing the C expression to be injected.
  def assign(obj)
    assign? ? "#{properties[:assign]}(#{obj})" : "(#{obj})"
  end
  # :nodoc:
  def write_intf_assign(stream)
    stream << "#{type} #{properties[:assign]}(#{type});" if assign?
  end
end # Assignable


##
# Indicates that the type class including this module provides the equality testing operation.
# The user-defined function is assigned to the key +:compare+
# and is expected to have the signature int _comparison-function_(+type+, +type+).
# The C function provided must return 0 when the values are considered equal and not zero otherwise.
# When no user-defined function is specified, this module generates simple value identity testing with == operator.
module Comparable
  Methods = [:compare] # :nodoc:
  ##
  # Returns +true+ when used-defined equality testing function is specified and +false+ otherwise.
  def compare?
    !properties[:compare].nil?
  end
  # Returns string representing the C expression comparison of +lt+ and +rt+.
  # +lt+ and +rt+ are the string-like objects containing the C expression to be injected.
  def compare(lt, rt)
    compare? ? "#{properties[:compare]}(#{lt},#{rt})" : "((#{lt}==#{rt}) ? 0 : 1)"
  end
  # :nodoc:
  def write_intf_compare(stream)
    stream << "int #{properties[:compare]}(#{type},#{type});" if compare?
  end
end # Comparable


##
# Indicates that the type class including this module provides the hash code calculation.
# The user-defined function is assigned to the key +:hash+
# and is expected to have the signature +size_t+ _hash-function_(+type+).
# The C function provided is expected to return a hash code of its argument.
# When no user-defined function is specified, this module generates simple casting to the +size_t+ type.
module Hashable
  Methods = [:hash] # :nodoc:
  ##
  # Returns +true+ when used-defined hashing function is specified and +false+ otherwise.
  def hash?
    !properties[:hash].nil?
  end
  # Returns string representing the C hashing expression for +obj+.
  # +obj+ is a string-like object containing the C expression to be injected.
  def hash(obj)
    hash? ? "#{properties[:hash]}(#{obj})" : "((size_t)(#{obj}))" # TODO really size_t?
  end
  # :nodoc:
  def write_intf_hash(stream)
    stream << "size_t #{properties[:hash]}(#{type});" if hash?
  end
end # Hashable


##
# Indicates that the type class including this module provides the type construction with default value.
# The user-defined function is assigned to the key +:ctor+
# and is expected to have the signature +type+ _ctor-function_(+void+).
# The C function provided is expected to return a new object initialized with default values.
# When no user-defined function is specified, this module generates no code at all leaving the storage uninitialized.
module Constructible
  Methods = [:ctor] # :nodoc:
  ##
  # Returns +true+ when used-defined construction function is specified and +false+ otherwise.
  def ctor?
    !properties[:ctor].nil?
  end
  # Returns string representing the C construction expression.
  def ctor
    ctor? ? "#{properties[:ctor]}()" : nil
  end
  # :nodoc:
  def write_intf_ctor(stream)
    stream << "#{type} #{properties[:ctor]}(void);" if ctor?
  end
end # Constructible


##
# Indicates that the type class including this module provides the type destruction.
# The user-defined function is assigned to the key +:dtor+
# and is expected to have the signature +void+ _dtor-function_(+type+).
# The C function provided is expected to fully destroy the object (decrease reference count, reclaim the storage, whatever).
# When no user-defined function is specified, this module generates no code at all.
# The object destruction is performed prior the container destruction, on object removal/replacement.
module Destructible
  Methods = [:dtor]
  def dtor?
    !properties[:dtor].nil?
  end
  def dtor(obj)
    dtor? ? "#{properties[:dtor]}(#{obj})" : nil
  end
  def write_intf_dtor(stream)
    stream << "void #{properties[:dtor]}(#{type});" if dtor?
  end
end # Destructible


##
# Base class for user-defined data types intended to be put into the generated data containers.
# A descendant of this class is assumed to include one or more the following capability modules to indicate that
# the type supports specific operation: rdoc-ref:Assignable rdoc-ref:Comparable rdoc-ref:Hashable rdoc-ref:Constructible rdoc-ref:Destructible
class Type
  ##
  # String representing C type. Must be a valid C type declaration.
  attr_reader :type
  ##
  # Constructs the user-defined data type.
  # +hash+ is a +Hash+ object describing the type to be created.
  # The only mandatory key is +:type+ which is set to the C type declaration.
  # The rest of specified keys is type-specific and is determined by included capability modules.
  #
  # === type description examples
  #
  # [1] A simple integer data type with value semantics and no user-defined functions attached: {:type=>'int'}.
  #
  # [2] A generic untyped pointer data type with value semantics: {:type=>'void*'}.
  #     A value of this type is not owned by container so no ownership management is performed.
  #
  # [3] A pointer to a structure with reference semantics and used-defined operations:
  #     {:type=>'struct Point*', :assign=>'PointPtrAssign', :dtor=>'PointPtrDtor'}.
  #     A value of this type will be owned by container.
  def initialize(hash)
    @properties = hash
    @type = properties[:type]
  end
  # :nodoc:
  def write_intf(stream)
    methods = []
    self.class.included_modules.each do |m|
      begin
        methods.concat(m::Methods)
      rescue NameError
      end
    end
    methods.each do |m|
      send("write_intf_#{m}", stream)
    end
  end
  protected
  ##
  # Used by included modules to retrieve the type description supplied to constructor.
  attr_reader :properties
end # Type


##
# Internal base class for data structures which need one types specification, such as vectors, sets etc.
class Structure < Code
  # :nodoc:
  attr_reader :element
  # :nodoc:
  def initialize(type, element_info)
    super(type)
    @element = new_element_type(element_info)
    @forward = yield if block_given?
  end
  # :nodoc:
  def entities; [PrologueCode] end
  # :nodoc:
  def write_intf(stream)
    stream << @forward
    element.write_intf(stream)
  end
  protected
  # new_element_type()
end # Struct


##
# Data structure representing simple light-weight vector with capabilities similar to C array, with optional bounds checking.
class Vector < Structure
  # :nodoc:
  def write_intf(stream)
    super
    stream << %$
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{element.type}* values;
        size_t element_count;
      };
      struct #{it} {
        #{type}* array;
        size_t index;
      };
      void #{ctor}(#{type}*, size_t);
      void #{dtor}(#{type}*);
      #{type}* #{new}(size_t);
      void #{destroy}(#{type}*);
      int #{within}(#{type}*, size_t);
      void #{itCtor}(#{it}*, #{type}*);
      int #{itHasNext}(#{it}*);
      #{element.type} #{itNext}(#{it}*);
      #{inline} #{element.type}* #{ref}(#{type}* self, size_t index) {
        #{assert}(self);
        #{assert}(#{within}(self, index));
        return &self->values[index];
      }
      #{inline} #{element.type} #{get}(#{type}* self, size_t index) {
        #{assert}(self);
        #{assert}(#{within}(self, index));
        return *#{ref}(self, index);
      }
      #{inline} void #{set}(#{type}* self, size_t index, #{element.type} value) {
        #{element.type}* ref;
        #{assert}(self);
        #{assert}(#{within}(self, index));
        ref = #{ref}(self, index);
        #{element.dtor("*ref")};
        *ref = #{element.assign(:value)};
      }
      #{inline} size_t #{size}(#{type}* self) {
        #{assert}(self);
        return self->element_count;
      }
    $
  end
  # :nodoc:
  def write_defs(stream)
    stream << %$
      void #{ctor}(#{type}* self, size_t element_count) {
        #{assert}(self);
        #{assert}(element_count > 0);
        self->element_count = element_count;
        self->values = (#{element.type}*)#{malloc}(element_count*sizeof(#{element.type})); #{assert}(self->values);
        #{construct_stmt};
      }
      void #{dtor}(#{type}* self) {
        #{assert}(self);
        #{destruct_stmt};
        #{free}(self->values);
      }
      #{type}* #{new}(size_t element_count) {
        #{type}* self = (#{type}*)#{malloc}(sizeof(#{type})); #{assert}(self);
        #{ctor}(self, element_count);
        return self;
      }
      void #{destroy}(#{type}* self) {
        #{assert}(self);
        #{dtor}(self);
        #{free}(self);
      }
      int #{within}(#{type}* self, size_t index) {
        #{assert}(self);
        return index < self->element_count;
      }
      void #{itCtor}(#{it}* self, #{type}* array) {
        #{assert}(self);
        #{assert}(array);
        self->array = array;
        self->index = 0;
      }
      int #{itHasNext}(#{it}* self) {
        #{assert}(self);
        return self->index < #{size}(self->array);
      }
      #{element.type} #{itNext}(#{it}* self) {
        #{assert}(self);
        return #{get}(self->array, self->index++);
      }
    $
  end
  protected
  class ElementType < DataStructBuilder::Type
    include Assignable, Constructible, Destructible
  end # ElementType
  def new_element_type(hash)
    ElementType.new(hash)
  end
  private
  def construct_stmt
    if element.ctor?
      %${
        size_t index;
        for(index = 0; index < self->element_count; ++index) self->values[index] = #{element.ctor()};
      }$
    end
  end
  def destruct_stmt
    if element.dtor?
      %${
        size_t index;
        for(index = 0; index < self->element_count; ++index) #{element.dtor("self->values[index]")};
      }$
    end
  end
end # Vector


class List < Structure
  def write_intf(stream)
    super
    stream << %$
      typedef struct #{node} #{node};
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{node}* head_node;
        #{node}* tail_node;
        size_t node_count;
      };
      struct #{it} {
        #{node}* next_node;
      };
      struct #{node} {
        #{element.type} element;
        #{node}* next_node;
      };
      void #{ctor}(#{type}*);
      void #{dtor}(#{type}*);
      #{type}* #{new}(void);
      void #{destroy}(#{type}*);
      #{element.type} #{first}(#{type}*);
      #{element.type} #{last}(#{type}*);
      void #{append}(#{type}*, #{element.type});
      void #{prepend}(#{type}*, #{element.type});
      int #{contains}(#{type}*, #{element.type});
      #{element.type} #{get}(#{type}*, #{element.type});
      int #{replace}(#{type}*, #{element.type}, #{element.type});
      int #{replaceAll}(#{type}*, #{element.type}, #{element.type});
      size_t #{size}(#{type}*);
      int #{empty}(#{type}*);
      void #{itCtor}(#{it}*, #{type}*);
      int #{itHasNext}(#{it}*);
      #{element.type} #{itNext}(#{it}*);
    $
  end
  def write_defs(stream)
    stream << %$
      void #{ctor}(#{type}* self) {
        #{assert}(self);
        self->head_node = self->tail_node = NULL;
        self->node_count = 0;
      }
      void #{dtor}(#{type}* self) {
        #{node}* node;
        #{assert}(self);
        #{destruct_stmt};
        node = self->head_node;
        while(node) {
          #{node}* this_node = node;
          node = node->next_node;
          #{free}(this_node);
        }
      }
      #{type}* #{new}(void) {
        #{type}* self = (#{type}*)#{malloc}(sizeof(#{type})); #{assert}(self);
        #{ctor}(self);
        return self;
      }
      void #{destroy}(#{type}* self) {
        #{assert}(self);
        #{dtor}(self);
        #{free}(self);
      }
      #{element.type} #{first}(#{type}* self) {
        #{assert}(self);
        return self->head_node->element;
      }
      #{element.type} #{last}(#{type}* self) {
        #{assert}(self);
        return self->tail_node->element;
      }
      void #{append}(#{type}* self, #{element.type} element) {
        #{node}* node;
        #{assert}(self);
        node = (#{node}*)#{malloc}(sizeof(#{node})); #{assert}(node);
        node->element = #{element.assign(:element)};
        node->next_node = NULL;
        if(self->tail_node) self->tail_node->next_node = node;
        self->tail_node = node;
        if(!self->head_node) self->head_node = self->tail_node;
        ++self->node_count;
      }
      void #{prepend}(#{type}* self, #{element.type} element) {
        #{node}* node;
        #{assert}(self);
        node = (#{node}*)#{malloc}(sizeof(#{node})); #{assert}(node);
        node->element = #{element.assign(:element)};
        node->next_node = self->head_node;
        self->head_node = node;
        if(!self->tail_node) self->tail_node = node;
        ++self->node_count;
      }
      int #{contains}(#{type}* self, #{element.type} what) {
        #{node}* node;
        #{assert}(self);
        node = self->head_node;
        while(node) {
          if(#{element.compare("node->element", "what")} == 0) {
            return 1;
          }
          node = node->next_node;
        }
        return 0;
      }
      #{element.type} #{get}(#{type}* self, #{element.type} what) {
        #{node}* node;
        #{assert}(self);
        #{assert}(#{contains}(self, what));
        node = self->head_node;
        while(node) {
          if(#{element.compare("node->element", "what")} == 0) {
            return node->element;
          }
          node = node->next_node;
        }
        #{abort}();
      }
      int #{replace}(#{type}* self, #{element.type} what, #{element.type} with) {
        #{node}* node;
        #{assert}(self);
        node = self->head_node;
        while(node) {
          if(#{element.compare("node->element", "what")} == 0) {
            #{element.dtor("node->element")};
            node->element = #{element.assign(:with)};
            return 1;
          }
          node = node->next_node;
        }
        return 0;
      }
      int #{replaceAll}(#{type}* self, #{element.type} what, #{element.type} with) {
        #{node}* node;
        int count = 0;
        #{assert}(self);
        node = self->head_node;
        while(node) {
          if(#{element.compare("node->element", "what")} == 0) {
            #{element.dtor("node->element")};
            node->element = #{element.assign(:with)};
            ++count;
          }
          node = node->next_node;
        }
        return count;
      }
      size_t #{size}(#{type}* self) {
        #{assert}(self);
        return self->node_count;
      }
      int #{empty}(#{type}* self) {
        #{assert}(self);
        return !self->node_count;
      }
      void #{itCtor}(#{it}* self, #{type}* list) {
        #{assert}(self);
        #{assert}(list);
        self->next_node = list->head_node;
      }
      int #{itHasNext}(#{it}* self) {
        #{assert}(self);
        return self->next_node != NULL;
      }
      #{element.type} #{itNext}(#{it}* self) {
        #{node}* node;
        #{assert}(self);
        node = self->next_node;
        self->next_node = self->next_node->next_node;
        return node->element;
      }
    $
  end
  protected
  class ElementType < DataStructBuilder::Type
    include Assignable, Destructible, Comparable
  end # ElementType
  def new_element_type(hash)
    ElementType.new(hash)
  end
  private
  def destruct_stmt
    if element.dtor?
      %${
        #{it} it;
        #{itCtor}(&it, self);
        while(#{itHasNext}(&it)) {
          #{element.type} e = #{itNext}(&it);
          #{element.dtor(:e)};
        }
      }$
    end
  end
end # List


class HashSet < Structure
  def initialize(type, element_info)
    super
    @bucket = new_bucket
  end
  def write_intf(stream)
    super
    @bucket.write_intf(stream)
    stream << %$
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{@bucket.type}* buckets;
        size_t bucket_count;
        size_t size;
      };
      struct #{it} {
        #{type}* set;
        int bucket_index;
        #{@bucket.it} it;
      };
      void #{ctor}(#{type}*, size_t);
      void #{dtor}(#{type}*);
      #{type}* #{new}(size_t);
      void #{destroy}(#{type}*);
      int #{contains}(#{type}*, #{element.type});
      #{element.type} #{get}(#{type}*, #{element.type});
      size_t #{size}(#{type}*);
      int #{empty}(#{type}*);
      int #{put}(#{type}*, #{element.type});
      void #{putForce}(#{type}*, #{element.type});
      void #{itCtor}(#{it}*, #{type}*);
      int #{itHasNext}(#{it}*);
      #{element.type} #{itNext}(#{it}*);
    $
  end
  def write_defs(stream)
    @bucket.write_defs(stream)
    stream << %$
      void #{ctor}(#{type}* self, size_t bucket_count) {
        size_t i;
        #{assert}(self);
        #{assert}(bucket_count > 0);
        self->bucket_count = bucket_count;
        self->buckets = (#{@bucket.type}*)#{malloc}(bucket_count*sizeof(#{@bucket.type})); #{assert}(self->buckets);
        for(i = 0; i < self->bucket_count; ++i) {
          #{@bucket.ctor}(&self->buckets[i]);
        }
        self->size = 0;
      }
      void #{dtor}(#{type}* self) {
        size_t i;
        #{assert}(self);
        for(i = 0; i < self->bucket_count; ++i) {
          #{@bucket.dtor}(&self->buckets[i]);
        }
        #{free}(self->buckets);
      }
      #{type}* #{new}(size_t bucket_count) {
        #{type}* self = (#{type}*)#{malloc}(sizeof(#{type})); #{assert}(self);
        #{ctor}(self, bucket_count);
        return self;
      }
      void #{destroy}(#{type}* self) {
        #{assert}(self);
        #{dtor}(self);
        #{free}(self);
      }
      int #{contains}(#{type}* self, #{element.type} element) {
        #{assert}(self);
        return #{@bucket.contains}(&self->buckets[#{element.hash(:element)} % self->bucket_count], element);
      }
      #{element.type} #{get}(#{type}* self, #{element.type} element) {
        #{assert}(self);
        #{assert}(#{contains}(self, element));
        return #{@bucket.get}(&self->buckets[#{element.hash(:element)} % self->bucket_count], element);
      }
      size_t #{size}(#{type}* self) {
        #{assert}(self);
        return self->size;
      }
      int #{empty}(#{type}* self) {
        #{assert}(self);
        return !self->size;
      }
      int #{put}(#{type}* self, #{element.type} element) {
        #{@bucket.type}* bucket;
        #{assert}(self);
        bucket = &self->buckets[#{element.hash(:element)} % self->bucket_count];
        if(!#{@bucket.contains}(bucket, element)) {
          #{@bucket.append}(bucket, element);
          ++self->size;
          return 1;
        } else {
          return 0;
        }
      }
      void #{putForce}(#{type}* self, #{element.type} element) {
        #{@bucket.type}* bucket;
        #{assert}(self);
        bucket = &self->buckets[#{element.hash(:element)} % self->bucket_count];
        if(!#{@bucket.replace}(bucket, element, element)) {
          #{@bucket.append}(bucket, element);
          ++self->size;
        }
      }
      void #{itCtor}(#{it}* self, #{type}* set) {
        #{assert}(self);
        self->set = set;
        self->bucket_index = 0;
        #{@bucket.itCtor}(&self->it, &set->buckets[0]);
      }
      int #{itHasNext}(#{it}* self) {
        #{assert}(self);
        if(#{@bucket.itHasNext}(&self->it)) {
          return 1;
        } else {
          size_t i; for(i = self->bucket_index+1; i < self->set->bucket_count; ++i) {
            if(!#{@bucket.empty}(&self->set->buckets[i])) {
              return 1;
            }
          }
          return 0;
        }
      }
      #{element.type} #{itNext}(#{it}* self) {
        #{assert}(self);
        #{assert}(#{itHasNext}(self));
          if(#{@bucket.itHasNext}(&self->it)) {
            return #{@bucket.itNext}(&self->it);
          } else {
            size_t i; for(i = self->bucket_index+1; i < self->set->bucket_count; ++i) {
            if(!#{@bucket.empty}(&self->set->buckets[i])) {
            #{@bucket.itCtor}(&self->it, &self->set->buckets[i]);
              self->bucket_index = i;
              return #{@bucket.itNext}(&self->it);
            }
          }
          #{abort}();
        }
      }
    $
  end
  protected
  class ElementType < DataStructBuilder::Type
    include Assignable, Destructible, Hashable, Comparable
  end # ElementType
  def new_element_type(hash)
    @element_hash = hash
    ElementType.new(hash)
  end
  def new_bucket
    List.new("#{type}Bucket", @element_hash)
  end
end # Set


class HashMap < Code
  attr_reader :key, :value
  def entities; [PrologueCode] end
  def initialize(type, key_info, value_info)
    super(type)
    @entry_hash = {:type=>"#{type}Entry", :hash=>"#{type}EntryHash", :compare=>"#{type}EntryCompare"}
    @entry = new_entry_type
    @entrySet = new_entry_set
    @key = new_key_type(key_info)
    @value = new_value_type(value_info)
    @forward = yield if block_given?
  end
  def write_intf(stream)
    stream << @forward
    key.write_intf(stream)
    value.write_intf(stream)
    stream << %$
      typedef struct #{@entry.type} #{@entry.type};
      struct #{@entry.type} {
        #{key.type} key;
        #{value.type} value;
      };
    $
    @entrySet.write_intf(stream)
    stream << %$
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{@entrySet.type} entries;
      };
      struct #{it} {
        #{@entrySet.it} it;
      };
      void #{ctor}(#{type}*, size_t);
      void #{dtor}(#{type}*);
      #{type}* #{new}(size_t);
      void #{destroy}(#{type}*);
      size_t #{size}(#{type}*);
      int #{containsKey}(#{type}*, #{key.type});
      #{value.type} #{get}(#{type}*, #{key.type});
      int #{put}(#{type}*, #{key.type}, #{value.type});
      void #{putForce}(#{type}*, #{key.type}, #{value.type});
      void #{itCtor}(#{it}*, #{type}*);
      int #{itHasNext}(#{it}*);
      #{key.type} #{itNextKey}(#{it}*);
      #{value.type} #{itNextElement}(#{it}*);
      #{@entry.type} #{itNext}(#{it}*);
    $
  end
  def write_defs(stream)
    stream << %$
      size_t #{type}EntryHash(#{@entry.type} entry) {
        return #{key.hash("entry.key")};
      }
      int #{type}EntryCompare(#{@entry.type} lt, #{@entry.type} rt) {
        return #{key.compare("lt.key", "rt.key")};
      }
    $
    @entrySet.write_defs(stream)
    stream << %$
      void #{ctor}(#{type}* self, size_t bucket_count) {
        #{assert}(self);
        #{@entrySet.ctor}(&self->entries, bucket_count);
      }
      void #{dtor}(#{type}* self) {
        #{assert}(self);
        #{@entrySet.dtor}(&self->entries);
      }
      #{type}* #{new}(size_t bucket_count) {
        #{type}* self = (#{type}*)#{malloc}(sizeof(#{type})); #{assert}(self);
        #{ctor}(self, bucket_count);
        return self;
      }
      void #{destroy}(#{type}* self) {
        #{assert}(self);
        #{dtor}(self);
        #{free}(self);
      }
      size_t #{size}(#{type}* self) {
        return #{@entrySet.size}(&self->entries);
      }
      int #{containsKey}(#{type}* self, #{key.type} key) {
        #{@entry.type} entry;
        #{assert}(self);
        entry.key = key;
        return #{@entrySet.contains}(&self->entries, entry);
      }
      #{value.type} #{get}(#{type}* self, #{key.type} key) {
        #{@entry.type} entry;
        #{assert}(self);
        #{assert}(#{containsKey}(self, key));
        entry.key = key;
        return #{@entrySet.get}(&self->entries, entry).value;
      }
      int #{put}(#{type}* self, #{key.type} key, #{value.type} value) {
        #{assert}(self);
        if(!#{containsKey}(self, key)) {
          #{@entry.type} entry;
          entry.key = key; entry.value = value;
          #{@entrySet.put}(&self->entries, entry);
          return 1;
        } else {
          return 0;
        }
      }
      void #{putForce}(#{type}* self, #{key.type} key, #{value.type} value) {
        #{@entry.type} entry;
        #{assert}(self);
        entry.key = key; entry.value = value;
        #{@entrySet.putForce}(&self->entries, entry);
      }
      void #{itCtor}(#{it}* self, #{type}* map) {
        #{assert}(self);
        #{assert}(map);
        #{@entrySet.itCtor}(&self->it, &map->entries);
      }
      int #{itHasNext}(#{it}* self) {
        #{assert}(self);
        return #{@entrySet.itHasNext}(&self->it);
      }
      #{key.type} #{itNextKey}(#{it}* self) {
        #{assert}(self);
        return #{@entrySet.itNext}(&self->it).key;
      }
      #{value.type} #{itNextValue}(#{it}* self) {
        #{assert}(self);
        return #{@entrySet.itNext}(&self->it).value;
      }
      #{@entry.type} #{itNext}(#{it}* self) {
        #{assert}(self);
        return #{@entrySet.itNext}(&self->it);
      }
    $
  end
  protected
  class EntryType < DataStructBuilder::Type
    include Assignable, Hashable, Comparable
  end # EntryType
  class KeyType < DataStructBuilder::Type
    include Assignable, Destructible, Hashable, Comparable
  end # KeyType
  class ValueType < DataStructBuilder::Type
    include Assignable, Destructible
  end # ValueType
  def new_entry_type
    EntryType.new(@entry_hash)
  end
  def new_key_type(hash)
    KeyType.new(hash)
  end
  def new_value_type(hash)
    ValueType.new(hash)
  end
  def new_entry_set
    HashSet.new("#{type}EntrySet", @entry_hash)
  end
end # Map


end # DataStruct