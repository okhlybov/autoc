require 'autoc/code_builder'

=begin rdoc
Generators for strongly-typed C data containers similar to C++ STL container classes.

The data types used as elements for generated containers may be of almost arbitrary type,
with either value or reference semantics. A data type may be supplied with a host of user-defined functions
performing specific operations such as cloning, destruction and a like on it.
If no such function is specified, a default operation is generated.

A data structure generator with name <code>type</code> creates a C struct named <code>type</code> and a host of functions named <code>type*()</code>.
From now on, the following convention is applied:
when referring to a generated C function the container name portion of a function is abbreviated by the hash sign <code>#</code>, for example, the full method
<code>BlackBoxPut()</code> of a data container <code>BlackBox</code> will be abbreviated as <code>#Put()</code>.

Some notes on generated data structures:

* Use proper pair of construction and destruction functions: those containers created on stack with <code>#Ctor()</code>
  must be destroyed with <code>#Dtor()</code> while those created on heap with <code>#New()</code> must be destroyed with <code>#Destroy()</code>.
=end
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


=begin rdoc
Base class for all C data container generators.
=end
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


=begin rdoc
Indicates that the type class including this module provides the assignment operation.
The user-defined function is assigned to the key +:assign+ and
is expected to have the signature +type+ _assignment-function_(+type+).
The C function provided might return its argument or a new copy. It is also responsible for such things like ownership management etc.
When no user-defined function is specified, this module generates simple value assignment with = operator.
=end
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


=begin rdoc
Indicates that the type class including this module provides the equality testing operation.
The user-defined function is assigned to the key +:compare+
and is expected to have the signature int _comparison-function_(+type+, +type+).
The C function provided must return 0 when the values are considered equal and not zero otherwise.
When no user-defined function is specified, this module generates simple value identity testing with == operator.
=end
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


=begin rdoc
Indicates that the type class including this module provides the hash code calculation.
The user-defined function is assigned to the key +:hash+
and is expected to have the signature +size_t+ _hash-function_(+type+).
The C function provided is expected to return a hash code of its argument.
When no user-defined function is specified, this module generates simple casting to the +size_t+ type.
=end
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


=begin rdoc
Indicates that the type class including this module provides the type construction with default value.
The user-defined function is assigned to the key +:ctor+
and is expected to have the signature +type+ _ctor-function_(+void+).
The C function provided is expected to return a new object initialized with default values.
When no user-defined function is specified, this module generates no code at all leaving the storage uninitialized.
=end
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


=begin rdoc
Indicates that the type class including this module provides the type destruction.
The user-defined function is assigned to the key +:dtor+
and is expected to have the signature +void+ _dtor-function_(+type+).
The C function provided is expected to fully destroy the object (decrease reference count, reclaim the storage, whatever).
When no user-defined function is specified, this module generates no code at all.
The object destruction is performed prior the container destruction, on object removal/replacement.
=end
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


=begin rdoc
Base class for user-defined data types intended to be put into the generated data containers.
A descendant of this class is assumed to include one or more the following capability modules to indicate that
the type supports specific operation: rdoc-ref:Assignable rdoc-ref:Comparable rdoc-ref:Hashable rdoc-ref:Constructible rdoc-ref:Destructible
=end
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


# :nodoc:
class ForwardCode < CodeBuilder::Code
  attr_reader :forward
  def priority
    CodeBuilder::Priority::MAX
  end
  def initialize(forward)
    @forward = forward
  end
  def write_intf(stream)
    stream << forward
  end
  def hash
    forward.hash
  end
  def ==(other)
    equal?(other) || self.class == other.class && self.forward == other.forward
  end
  alias :eql? :==
end # ForwardCode


##
# Internal base class for data structures which need one types specification, such as vectors, sets etc.
class Structure < Code
  # :nodoc:
  attr_reader :element
  # :nodoc:
  def initialize(type, element_info)
    super(type)
    @element = new_element_type(element_info)
    @element_forward = ForwardCode.new(element_info[:forward]) unless element_info[:forward].nil?
  end
  # :nodoc:
  def entities; [PrologueCode, @element_forward].compact end
  # :nodoc:
  def write_intf(stream)
    element.write_intf(stream)
  end
  protected
  # new_element_type()
end # Struct


=begin rdoc
Data structure representing simple light-weight vector with capabilities similar to C array, with optional bounds checking.
=end
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
        size_t ref_count;
      };
      struct #{it} {
        #{type}* vector;
        size_t index;
      };
      void #{ctor}(#{type}*, size_t);
      void #{dtor}(#{type}*);
      #{type}* #{new}(size_t);
      void #{destroy}(#{type}*);
      #{type}* #{assign}(#{type}*);
      void #{resize}(#{type}*, size_t);
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
        #{construct_stmt("self->values", 0, "self->element_count-1")};
      }
      void #{dtor}(#{type}* self) {
        #{assert}(self);
        #{destruct_stmt("self->values", 0, "self->element_count-1")};
        #{free}(self->values);
      }
      #{type}* #{new}(size_t element_count) {
        #{type}* self = (#{type}*)#{malloc}(sizeof(#{type})); #{assert}(self);
        #{ctor}(self, element_count);
        self->ref_count = 0;
        return self;
      }
      void #{destroy}(#{type}* self) {
        #{assert}(self);
        if(!--self->ref_count) {
          #{dtor}(self);
          #{free}(self);
        }
      }
      #{type}* #{assign}(#{type}* self) {
        ++self->ref_count;
        return self;
      }
      void #{resize}(#{type}* self, size_t element_count) {
        #{assert}(self);
        if(self->element_count != element_count) {
          size_t count;
          #{element.type}* values = (#{element.type}*)#{malloc}(element_count*sizeof(#{element.type})); #{assert}(values);
          if(self->element_count > element_count) {
            #{destruct_stmt("self->values", "element_count", "self->element_count-1")};
            count = element_count;
          } else {
            #{construct_stmt("values", "self->element_count", "element_count-1")};
            count = self->element_count;
          }
          {
            size_t index;
            for(index = 0; index < count; ++index) {
              values[index] = self->values[index];
            }
          }
          #{free}(self->values);
          self->element_count = element_count;
          self->values = values;
        }
      }
      int #{within}(#{type}* self, size_t index) {
        #{assert}(self);
        return index < self->element_count;
      }
      void #{itCtor}(#{it}* self, #{type}* vector) {
        #{assert}(self);
        #{assert}(vector);
        self->vector = vector;
        self->index = 0;
      }
      int #{itHasNext}(#{it}* self) {
        #{assert}(self);
        return self->index < #{size}(self->vector);
      }
      #{element.type} #{itNext}(#{it}* self) {
        #{assert}(self);
        return #{get}(self->vector, self->index++);
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
  def construct_stmt(values, from, to)
    if element.ctor?
      %${
        size_t index;
        for(index = #{from}; index <= #{to}; ++index) #{values}[index] = #{element.assign(element.ctor())};
      }$
    end
  end
  def destruct_stmt(values, from, to)
    if element.dtor?
      %${
        size_t index;
        for(index = #{from}; index <= #{to}; ++index) #{element.dtor(values+"[index]")};
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
        size_t node_count;
        size_t ref_count;
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
      void #{prune}(#{type}*);
      #{type}* #{new}(void);
      void #{destroy}(#{type}*);
      #{type}* #{assign}(#{type}*);
      #{element.type} #{get}(#{type}*);
      void #{add}(#{type}*, #{element.type});
      void #{chop}(#{type}*);
      int #{contains}(#{type}*, #{element.type});
      #{element.type} #{find}(#{type}*, #{element.type});
      int #{replace}(#{type}*, #{element.type}, #{element.type});
      int #{replaceAll}(#{type}*, #{element.type}, #{element.type});
      int #{remove}(#{type}*, #{element.type});
      int #{removeAll}(#{type}*, #{element.type});
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
        self->head_node = NULL;
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
        self->ref_count = 0;
        return self;
      }
      void #{destroy}(#{type}* self) {
        #{assert}(self);
        if(!--self->ref_count) {
          #{dtor}(self);
          #{free}(self);
        }
      }
      #{type}* #{assign}(#{type}* self) {
        ++self->ref_count;
        return self;
      }
      void #{prune}(#{type}* self) {
        #{dtor}(self);
        #{ctor}(self);
      }
      #{element.type} #{get}(#{type}* self) {
        #{assert}(self);
        #{assert}(!#{empty}(self));
        return self->head_node->element;
      }
      void #{chop}(#{type}* self) {
        #{node}* node;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        node = self->head_node;
        #{element.dtor("node->element")};
        self->head_node = self->head_node->next_node;
        --self->node_count;
        #{free}(node);
      }
      void #{add}(#{type}* self, #{element.type} element) {
        #{node}* node;
        #{assert}(self);
        node = (#{node}*)#{malloc}(sizeof(#{node})); #{assert}(node);
        node->element = #{element.assign("element")};
        node->next_node = self->head_node;
        self->head_node = node;
        ++self->node_count;
      }
      int #{contains}(#{type}* self, #{element.type} what) {
        #{node}* node;
        #{assert}(self);
        what = #{element.assign("what")};
        node = self->head_node;
        while(node) {
          if(#{element.compare("node->element", "what")} == 0) {
            #{element.dtor("what")};
            return 1;
          }
          node = node->next_node;
        }
        #{element.dtor("what")};
        return 0;
      }
      #{element.type} #{find}(#{type}* self, #{element.type} what) {
        #{node}* node;
        #{assert}(self);
        what = #{element.assign("what")};
        #{assert}(#{contains}(self, what));
        node = self->head_node;
        while(node) {
          if(#{element.compare("node->element", "what")} == 0) {
            #{element.dtor("what")};
            return node->element;
          }
          node = node->next_node;
        }
        #{abort}();
      }
      int #{replace}(#{type}* self, #{element.type} what, #{element.type} with) {
        #{node}* node;
        #{assert}(self);
        what = #{element.assign("what")};
        with = #{element.assign("with")};
        node = self->head_node;
        while(node) {
          if(#{element.compare("node->element", "what")} == 0) {
            #{element.dtor("node->element")};
            node->element = #{element.assign("with")};
            #{element.dtor("what")};
            #{element.dtor("with")};
            return 1;
          }
          node = node->next_node;
        }
        #{element.dtor("what")};
        #{element.dtor("with")};
        return 0;
      }
      int #{replaceAll}(#{type}* self, #{element.type} what, #{element.type} with) {
        #{node}* node;
        int count = 0;
        #{assert}(self);
        what = #{element.assign("what")};
        with = #{element.assign("with")};
        node = self->head_node;
        while(node) {
          if(#{element.compare("node->element", "what")} == 0) {
            #{element.dtor("node->element")};
            node->element = #{element.assign("with")};
            ++count;
          }
          node = node->next_node;
        }
        #{element.dtor("what")};
        #{element.dtor("with")};
        return count;
      }
      int #{remove}(#{type}* self, #{element.type} what) {
        #{node}* node;
        #{node}* prev_node;
        int found = 0;
        #{assert}(self);
        what = #{element.assign("what")};
        node = self->head_node;
        prev_node = NULL;
        while(node) {
          if(#{element.compare("node->element", "what")} == 0) {
            #{element.dtor("node->element")};
            if(prev_node) {
              prev_node->next_node = node->next_node ? node->next_node : NULL;
            } else {
              self->head_node = node->next_node ? node->next_node : NULL;
            }
            --self->node_count;
            #{free}(node);
            found = 1;
            break;
          }
          prev_node = node;
          node = node->next_node;
        }
        #{element.dtor("what")};
        return found;
      }
      int #{removeAll}(#{type}* self, #{element.type} what) {
        #{node}* node;
        #{node}* prev_node;
        int count = 0;
        #{assert}(self);
        what = #{element.assign("what")};
        node = self->head_node;
        prev_node = NULL;
        while(node) {
          if(#{element.compare("node->element", "what")} == 0) {
            #{element.dtor("node->element")};
            if(prev_node) {
              prev_node->next_node = node->next_node ? node->next_node : NULL;
            } else {
              self->head_node = node->next_node ? node->next_node : NULL;
            }
            --self->node_count;
            #{free}(node);
            ++count;
          }
          prev_node = node;
          node = node->next_node;
        }
        #{element.dtor("what")};
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
        size_t bucket_count, min_bucket_count;
        size_t size, min_size, max_size;
        unsigned min_fill, max_fill, capacity_multiplier; /* ?*1e-2 */
        size_t ref_count;
      };
      struct #{it} {
        #{type}* set;
        int bucket_index;
        #{@bucket.it} it;
      };
      void #{ctor}(#{type}*);
      void #{dtor}(#{type}*);
      #{type}* #{new}(void);
      void #{destroy}(#{type}*);
      #{type}* #{assign}(#{type}*);
      void #{purge}(#{type}*);
      void #{rehash}(#{type}*);
      int #{contains}(#{type}*, #{element.type});
      #{element.type} #{get}(#{type}*, #{element.type});
      size_t #{size}(#{type}*);
      int #{empty}(#{type}*);
      int #{put}(#{type}*, #{element.type});
      void #{replace}(#{type}*, #{element.type});
      int #{remove}(#{type}*, #{element.type});
      void #{itCtor}(#{it}*, #{type}*);
      int #{itHasNext}(#{it}*);
      #{element.type} #{itNext}(#{it}*);
    $
  end
  def write_defs(stream)
    @bucket.write_defs(stream)
    stream << %$
      void #{ctor}(#{type}* self) {
        #{assert}(self);
        self->min_bucket_count = 16;
        self->min_fill = 20;
        self->max_fill = 80;
        self->min_size = (float)self->min_fill/100*self->min_bucket_count;
        self->max_size = (float)self->max_fill/100*self->min_bucket_count;
        self->capacity_multiplier = 200;
        self->buckets = NULL;
        #{rehash}(self);
      }
      void #{dtor}(#{type}* self) {
        size_t i;
        #{assert}(self);
        for(i = 0; i < self->bucket_count; ++i) {
          #{@bucket.dtor}(&self->buckets[i]);
        }
        #{free}(self->buckets);
      }
      #{type}* #{new}(void) {
        #{type}* self = (#{type}*)#{malloc}(sizeof(#{type})); #{assert}(self);
        #{ctor}(self);
        self->ref_count = 0;
        return self;
      }
      void #{destroy}(#{type}* self) {
        #{assert}(self);
        if(!--self->ref_count) {
          #{dtor}(self);
          #{free}(self);
        }
      }
      #{type}* #{assign}(#{type}* self) {
        ++self->ref_count;
        return self;
      }
      void #{purge}(#{type}* self) {
        #{assert}(self);
        #{dtor}(self);
        self->buckets = NULL;
        #{rehash}(self);
      }
      void #{rehash}(#{type}* self) {
        #{@bucket.type}* buckets;
        size_t i, bucket_count, size, fill;
        #{assert}(self);
        #{assert}(self->min_fill > 0);
        #{assert}(self->max_fill > 0);
        #{assert}(self->min_fill < self->max_fill);
        #{assert}(self->min_bucket_count > 0);
        if(self->buckets) {
          if(self->min_size < self->size && self->size < self->max_size) return;
          fill = (float)self->size/(float)self->bucket_count*100;
          if(fill > self->max_fill) {
            bucket_count = (float)self->bucket_count/100*(float)self->capacity_multiplier;
          } else
          if(fill < self->min_fill && self->bucket_count > self->min_bucket_count) {
            bucket_count = (float)self->bucket_count/(float)self->capacity_multiplier*100;
            if(bucket_count < self->min_bucket_count) bucket_count = self->min_bucket_count;
          } else
            return;
          size = self->size;
          self->min_size = (float)self->min_fill/100*size;
          self->max_size = (float)self->max_fill/100*size;
        } else {
          bucket_count = self->min_bucket_count;
          size = 0;
        }
        buckets = (#{@bucket.type}*)#{malloc}(bucket_count*sizeof(#{@bucket.type})); #{assert}(buckets);
        for(i = 0; i < bucket_count; ++i) {
          #{@bucket.ctor}(&buckets[i]);
        }
        if(self->buckets) {
          #{it} it;
          #{itCtor}(&it, self);
          while(#{itHasNext}(&it)) {
            #{@bucket.type}* bucket;
            #{element.type} element = #{itNext}(&it);
            bucket = &buckets[#{element.hash("element")} % bucket_count];
            #{@bucket.add}(bucket, element);
          }
          #{dtor}(self);
        }
        self->buckets = buckets;
        self->bucket_count = bucket_count;
        self->size = size;
      }
      int #{contains}(#{type}* self, #{element.type} element) {
        int result;
        #{assert}(self);
        element = #{element.assign("element")};
        result = #{@bucket.contains}(&self->buckets[#{element.hash("element")} % self->bucket_count], element);
        #{element.dtor("element")};
        return result;
      }
      #{element.type} #{get}(#{type}* self, #{element.type} element) {
        #{element.type} result;
        #{assert}(self);
        element = #{element.assign("element")};
        #{assert}(#{contains}(self, element));
        result = #{@bucket.find}(&self->buckets[#{element.hash("element")} % self->bucket_count], element);
        #{element.dtor("element")};
        return result;
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
        int contained = 1;
        #{@bucket.type}* bucket;
        #{assert}(self);
        element = #{element.assign("element")};
        bucket = &self->buckets[#{element.hash("element")} % self->bucket_count];
        if(!#{@bucket.contains}(bucket, element)) {
          #{@bucket.add}(bucket, element);
          ++self->size;
          contained = 0;
          #{rehash}(self);
        }
        #{element.dtor("element")};
        return contained;
      }
      void #{replace}(#{type}* self, #{element.type} element) {
        #{@bucket.type}* bucket;
        #{assert}(self);
        element = #{element.assign("element")};
        bucket = &self->buckets[#{element.hash("element")} % self->bucket_count];
        if(!#{@bucket.replace}(bucket, element, element)) {
          #{@bucket.add}(bucket, element);
          ++self->size;
          #{rehash}(self);
        }
        #{element.dtor("element")};
      }
      int #{remove}(#{type}* self, #{element.type} what) {
        int removed = 0;
        #{@bucket.type}* bucket;
        #{assert}(self);
        what = #{element.assign("what")};
        bucket = &self->buckets[#{element.hash("what")} % self->bucket_count];
        if(#{@bucket.remove}(bucket, what)) {
          --self->size;
          removed = 1;
          #{rehash}(self);
        }
        #{element.dtor("what")};
        return removed;
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
  def entities
    result = [PrologueCode]
    result << @key_forward unless @key_forward.nil?
    result << @value_forward unless @value_forward.nil?
    result
  end
  def initialize(type, key_info, value_info)
    super(type)
    @entry_hash = {:type=>"#{entry}", :hash=>"#{entryHash}", :compare=>"#{entryCompare}", :assign=>"#{entryAssign}", :dtor=>"#{entryDtor}"}
    @entry = new_entry_type
    @entrySet = new_entry_set
    @key = new_key_type(key_info)
    @value = new_value_type(value_info)
    @key_forward = ForwardCode.new(key_info[:forward]) unless key_info[:forward].nil?
    @value_forward = ForwardCode.new(value_info[:forward]) unless value_info[:forward].nil?
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
        int valid_value;
      };
    $
    @entrySet.write_intf(stream)
    stream << %$
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{@entrySet.type} entries;
        size_t ref_count;
      };
      struct #{it} {
        #{@entrySet.it} it;
      };
      void #{ctor}(#{type}*);
      void #{dtor}(#{type}*);
      #{type}* #{new}(void);
      void #{destroy}(#{type}*);
      #{type}* #{assign}(#{type}*);
      void #{purge}(#{type}*);
      void #{rehash}(#{type}*);
      size_t #{size}(#{type}*);
      int #{empty}(#{type}*);
      int #{containsKey}(#{type}*, #{key.type});
      #{value.type} #{get}(#{type}*, #{key.type});
      int #{put}(#{type}*, #{key.type}, #{value.type});
      void #{replace}(#{type}*, #{key.type}, #{value.type});
      int #{remove}(#{type}*, #{key.type});
      void #{itCtor}(#{it}*, #{type}*);
      int #{itHasNext}(#{it}*);
      #{key.type} #{itNextKey}(#{it}*);
      #{value.type} #{itNextElement}(#{it}*);
      #{@entry.type} #{itNext}(#{it}*);
    $
  end
  def write_defs(stream)
    stream << %$
      #{inline} #{@entry.type} #{entryKeyOnly}(#{key.type} key) {
        #{@entry.type} entry;
        entry.key = key;
        entry.valid_value = 0;
        return entry;
      }
      #{inline} #{@entry.type} #{entryKeyValue}(#{key.type} key, #{value.type} value) {
        #{@entry.type} entry;
        entry.key = key;
        entry.value = value;
        entry.valid_value = 1;
        return entry;
      }
      size_t #{entryHash}(#{@entry.type} entry) {
        return #{key.hash("entry.key")};
      }
      int #{entryCompare}(#{@entry.type} lt, #{@entry.type} rt) {
        return #{key.compare("lt.key", "rt.key")};
      }
      #{@entry.type} #{entryAssign}(#{@entry.type} entry) {
        entry.key = #{key.assign("entry.key")};
        if(entry.valid_value) entry.value = #{value.assign("entry.value")};
        return entry;
      }
      void #{entryDtor}(#{@entry.type} entry) {
        #{key.dtor("entry.key")};
        if(entry.valid_value) #{value.dtor("entry.value")};
      }
    $
    @entrySet.write_defs(stream)
    stream << %$
      void #{ctor}(#{type}* self) {
        #{assert}(self);
        #{@entrySet.ctor}(&self->entries);
      }
      void #{dtor}(#{type}* self) {
        #{assert}(self);
        #{@entrySet.dtor}(&self->entries);
      }
      #{type}* #{new}(void) {
        #{type}* self = (#{type}*)#{malloc}(sizeof(#{type})); #{assert}(self);
        #{ctor}(self);
        self->ref_count = 0;
        return self;
      }
      void #{destroy}(#{type}* self) {
        #{assert}(self);
        if(!--self->ref_count) {
          #{dtor}(self);
          #{free}(self);
        }
      }
      void #{rehash}(#{type}* self) {
        #{assert}(self);
        #{@entrySet.rehash}(&self->entries);
      }
      #{type}* #{assign}(#{type}* self) {
        #{assert}(self);
        ++self->ref_count;
        return self;
      }
      void #{purge}(#{type}* self) {
        #{assert}(self);
        #{@entrySet.purge}(&self->entries);
      }
      size_t #{size}(#{type}* self) {
        #{assert}(self);
        return #{@entrySet.size}(&self->entries);
      }
      int #{empty}(#{type}* self) {
        #{assert}(self);
        return #{@entrySet.empty}(&self->entries);
      }
      int #{containsKey}(#{type}* self, #{key.type} key) {
        int result;
        #{@entry.type} entry;
        #{assert}(self);
        entry = #{@entry.assign("#{entryKeyOnly}(key)")};
        result = #{@entrySet.contains}(&self->entries, entry);
        #{@entry.dtor("entry")};
        return result;
      }
      #{value.type} #{get}(#{type}* self, #{key.type} key) {
        #{value.type} result;
        #{@entry.type} entry;
        #{assert}(self);
        entry = #{@entry.assign("#{entryKeyOnly}(key)")};
        #{assert}(#{containsKey}(self, key));
        result = #{@entrySet.get}(&self->entries, entry).value;
        #{@entry.dtor("entry")};
        return result;
      }
      int #{put}(#{type}* self, #{key.type} key, #{value.type} value) {
        #{@entry.type} entry = #{@entry.assign("#{entryKeyValue}(key,value)")};
        #{assert}(self);
        if(!#{containsKey}(self, key)) {
          #{@entrySet.put}(&self->entries, entry);
          #{@entry.dtor("entry")};
          return 1;
        } else {
          #{@entry.dtor("entry")};
          return 0;
        }
      }
      void #{replace}(#{type}* self, #{key.type} key, #{value.type} value) {
        #{@entry.type} entry;
        #{assert}(self);
        entry = #{@entry.assign("#{entryKeyValue}(key,value)")};
        #{@entrySet.replace}(&self->entries, entry);
        #{@entry.dtor("entry")};
      }
      int #{remove}(#{type}* self, #{key.type} key) {
        int removed;
        #{@entry.type} entry;
        #{assert}(self);
        entry = #{@entry.assign("#{entryKeyOnly}(key)")};
        removed = #{@entrySet.remove}(&self->entries, entry);
        #{@entry.dtor("entry")};
        return removed;
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
    include Assignable, Destructible, Hashable, Comparable
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