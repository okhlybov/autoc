require "set"
require "autoc/code_builder"


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
        #if defined(__STDC__) || defined(_MSC_VER)
          #define __DATA_STRUCT_INLINE static
        #else
          #define __DATA_STRUCT_INLINE static inline
        #endif
      #endif
      #ifndef __DATA_STRUCT_EXTERN
        #if defined(__cplusplus)
          #define __DATA_STRUCT_EXTERN extern "C"
        #else
          #define __DATA_STRUCT_EXTERN extern
        #endif
      #endif
    $
    stream << %$
      #include <stdio.h>
    $ if $debug
  end
end.new # PrologueCode


=begin rdoc
Base class for all C data container generators.
=end
class Code < CodeBuilder::Code
  undef abort;
  # String-like prefix for generated data type. Must be a valid C identifier.
  attr_reader :type
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
      s = method.to_s.chomp('?')
      @type + s[0].capitalize + s[1..-1]
    end
  end
  # :nodoc:
  def setup_overrides
    @overrides = {:malloc=>"malloc", :calloc=>"calloc", :free=>"free", :assert=>"assert", :abort=>"abort", :extern=>"__DATA_STRUCT_EXTERN", :static=>"static", :inline=>"__DATA_STRUCT_INLINE"}
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
  # Returns +true+ when used-defined assignment function is specified and +false+ otherwise.
  def assign?
    !descriptor[:assign].nil?
  end
  # Returns string representing the C assignment expression for +obj+.
  # +obj+ is a string-like object containing the C expression to be injected.
  def assign(obj)
    assign? ? "#{descriptor[:assign]}(#{obj})" : "(#{obj})"
  end
  # :nodoc:
  def write_intf_assign(stream)
    stream << "#{type} #{descriptor[:assign]}(#{type});" if assign?
  end
end # Assignable


=begin rdoc
Indicates that the type class including this module provides the equality testing operation.
The user-defined function is assigned to the key +:equal+
and is expected to have the signature int _equality-function_(+type+, +type+).
The C function provided must return non-zero value when the values are considered equal and zero value otherwise.
When no user-defined function is specified, this module generates simple value identity testing with == operator.
=end
module EqualityTestable
  Methods = [:equal] # :nodoc:
  # Returns +true+ when used-defined equality testing function is specified and +false+ otherwise.
  def equal?
    !descriptor[:equal].nil?
  end
  # Returns string representing the C expression comparison of +lt+ and +rt+.
  # +lt+ and +rt+ are the string-like objects containing the C expression to be injected.
  def equal(lt, rt)
    equal? ? "#{descriptor[:equal]}(#{lt},#{rt})" : "(#{lt}==#{rt})"
  end
  # :nodoc:
  def write_intf_equal(stream)
    stream << "int #{descriptor[:equal]}(#{type},#{type});" if equal?
  end
end # EqualityTestable


=begin rdoc
Indicates that the type class including this module provides the comparison operation.
The user-defined function is assigned to the key +:compare+
and is expected to have the signature int _compare-function_(+type+, +type+).
The C function provided must return value greater than zero when the first argument is considered greater than the second,
value less than zero when the first argument is considered smaller than the second and zero value when the two arguments are
considered equal.
When no user-defined function is specified, this module generates simple value comparison with < and > operators.
=end
module Comparable
  Methods = [:compare] # :nodoc:
  # Returns +true+ when wither used-defined or default equality testing function is specified and +false+ otherwise.
  def compare?
    descriptor.include?(:compare)
  end
  # Returns string representing the C expression comparison of +lt+ and +rt+.
  # +lt+ and +rt+ are the string-like objects containing the C expression to be injected.
  def compare(lt, rt)
    compare = descriptor[:compare]
    compare.nil? ? "(#{lt} > #{rt} ? +1 : (#{lt} < #{rt} ? -1 : 0))" : "#{compare}(#{lt},#{rt})"
  end
  # :nodoc:
  def write_intf_compare(stream)
    compare = descriptor[:compare]
    stream << "int #{compare}(#{type},#{type});" unless compare.nil?
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
  # Returns +true+ when used-defined hashing function is specified and +false+ otherwise.
  def hash?
    !descriptor[:hash].nil?
  end
  # Returns string representing the C hashing expression for +obj+.
  # +obj+ is a string-like object containing the C expression to be injected.
  def hash(obj)
    hash? ? "#{descriptor[:hash]}(#{obj})" : "((size_t)(#{obj}))" # TODO really size_t?
  end
  # :nodoc:
  def write_intf_hash(stream)
    stream << "size_t #{descriptor[:hash]}(#{type});" if hash?
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
  # Returns +true+ when used-defined construction function is specified and +false+ otherwise.
  def ctor?
    !descriptor[:ctor].nil?
  end
  # Returns string representing the C construction expression.
  def ctor
    ctor? ? "#{descriptor[:ctor]}()" : nil
  end
  # :nodoc:
  def write_intf_ctor(stream)
    stream << "#{type} #{descriptor[:ctor]}(void);" if ctor?
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
  Methods = [:dtor] # :nodoc:
  # Returns +true+ when used-defined construction function is specified and +false+ otherwise.
  def dtor?
    !descriptor[:dtor].nil?
  end
  # Returns string representing the C construction expression.
  def dtor(obj)
    dtor? ? "#{descriptor[:dtor]}(#{obj})" : nil
  end
  # :nodoc:
  def write_intf_dtor(stream)
    stream << "void #{descriptor[:dtor]}(#{type});" if dtor?
  end
end # Destructible


=begin rdoc
Base class for user-defined data types intended to be put into the generated data containers.
A descendant of this class is assumed to include one or more the following capability modules to indicate that
the type supports specific operation: rdoc-ref:Assignable rdoc-ref:Equal rdoc-ref:Hashable rdoc-ref:Constructible rdoc-ref:Destructible
=end
class Type
  ##
  # String representing C type. Must be a valid C type declaration.
  attr_reader :type
  ##
  # Constructs the user-defined data type.
  # +descriptor+ is a +Hash+-like object describing the type to be created.
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
  def initialize(descriptor)
    @descriptor = descriptor
    @type = descriptor[:type]
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
  # May be nil.
  def code
    descriptor.is_a?(CodeBuilder::Code) ? descriptor : (descriptor[:forward] ? ForwardCode.new(descriptor[:forward]) : nil)
  end
  protected
  ##
  # Used by included modules to retrieve the type description supplied to constructor.
  attr_reader :descriptor
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


module Writers
  Visibilities = Set.new [:public, :private, :static]
  def initialize(type, visibility = :public)
    super(type)
    raise unless Visibilities.include?(visibility)
    @visibility = visibility
  end
  # :nodoc:
  def write_intf(stream)
    case @visibility
      when :public
        write_exported_types(stream)
        write_exported_declarations(stream, extern, inline)
    end
  end
  # :nodoc:
  def write_decls(stream)
    case @visibility
      when :private
        write_exported_types(stream)
        write_exported_declarations(stream, extern, inline)
      when :static
        write_exported_types(stream)
        write_exported_declarations(stream, static, inline)
    end
  end
  # :nodoc:
  def write_defs(stream)
    case @visibility
      when :public, :private
        write_implementations(stream, nil)
      when :static
        write_implementations(stream, static)
    end
  end
  # def write_exported_types(stream)
  # def write_exported_declarations(stream, declare, define)
  # def write_implementations(stream, define)
end # Writers


##
# Internal base class for data structures which need one types specification, such as vectors, sets etc.
class Structure < Code
  include Writers
  attr_reader :element
  # :nodoc:
  def initialize(type, element_descriptor, visibility = :public)
    super(type, visibility)
    @element = new_element_type(element_descriptor)
    @self_hash = {:type=>"#{type}*", :assign=>assign, :ctor=>new, :dtor=>destroy}
  end
  # :nodoc:
  def [](symbol)
    @self_hash[symbol]
  end
  # :nodoc:
  def entities; [PrologueCode, @element.code].compact end
  # :nodoc:
  def write_intf(stream)
    element.write_intf(stream)
    super
  end
  # def new_element_type()
end # Struct


=begin rdoc
Data structure representing simple light-weight vector with capabilities similar to C array, with optional bounds checking.
=end
class Vector < Structure
  def initialize(*args)
    super
    @self_hash.delete(:ctor) # unlike other data structures, Vector has no parameterless constructor
  end
  # :nodoc:
  def write_exported_types(stream)
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
    $
  end
  def write_exported_declarations(stream, declare, define)
    stream << %$
      #{declare} void #{ctor}(#{type}*, size_t);
      #{declare} void #{dtor}(#{type}*);
      #{declare} #{type}* #{new}(size_t);
      #{declare} void #{destroy}(#{type}*);
      #{declare} #{type}* #{assign}(#{type}*);
      #{declare} void #{resize}(#{type}*, size_t);
      #{declare} int #{within}(#{type}*, size_t);
      #{declare} void #{itCtor}(#{it}*, #{type}*);
      #{declare} int #{itHasNext}(#{it}*);
      #{declare} #{element.type} #{itNext}(#{it}*);
      #{define} #{element.type}* #{ref}(#{type}* self, size_t index) {
        #{assert}(self);
        #{assert}(#{within}(self, index));
        return &self->values[index];
      }
      #{define} #{element.type} #{get}(#{type}* self, size_t index) {
        #{assert}(self);
        #{assert}(#{within}(self, index));
        return *#{ref}(self, index);
      }
      #{define} void #{set}(#{type}* self, size_t index, #{element.type} value) {
        #{element.type}* ref;
        #{assert}(self);
        #{assert}(#{within}(self, index));
        ref = #{ref}(self, index);
        #{element.dtor("*ref")};
        *ref = #{element.assign(:value)};
      }
      #{define} size_t #{size}(#{type}* self) {
        #{assert}(self);
        return self->element_count;
      }
    $
    stream << %$#{declare} void #{sort}(#{type}*);$ if element.compare?
  end
  # :nodoc:
  def write_implementations(stream, define)
    stream << %$
      #{define} void #{ctor}(#{type}* self, size_t element_count) {
        #{assert}(self);
        #{assert}(element_count > 0);
        self->element_count = element_count;
        self->values = (#{element.type}*)#{calloc}(element_count, sizeof(#{element.type})); #{assert}(self->values);
        #{construct_stmt("self->values", 0, "self->element_count-1")};
      }
      #{define} void #{dtor}(#{type}* self) {
        #{assert}(self);
        #{destruct_stmt("self->values", 0, "self->element_count-1")};
        #{free}(self->values);
      }
      #{define} #{type}* #{new}(size_t element_count) {
        #{type}* self = (#{type}*)#{malloc}(sizeof(#{type})); #{assert}(self);
        #{ctor}(self, element_count);
        self->ref_count = 0;
        return self;
      }
      #{define} void #{destroy}(#{type}* self) {
        #{assert}(self);
        if(!--self->ref_count) {
          #{dtor}(self);
          #{free}(self);
        }
      }
      #{define} #{type}* #{assign}(#{type}* self) {
        ++self->ref_count;
        return self;
      }
      #{define} void #{resize}(#{type}* self, size_t element_count) {
        #{assert}(self);
        if(self->element_count != element_count) {
          size_t count;
          #{element.type}* values = (#{element.type}*)#{calloc}(element_count, sizeof(#{element.type})); #{assert}(values);
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
      #{define} int #{within}(#{type}* self, size_t index) {
        #{assert}(self);
        return index < self->element_count;
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
    $
    stream << %$
      static int #{comparator}(const void* lp, const void* rp) {
        return #{element.compare("*(#{element.type}*)lp", "*(#{element.type}*)rp")};
      }
      #{define} void #{sort}(#{type}* self) {
        #{assert}(self);
        qsort(self->values, self->element_count, sizeof(#{element.type}), #{comparator});
      }
    $ if element.compare?
  end
  protected
  # :nodoc:
  class ElementType < DataStructBuilder::Type
    include Assignable, Constructible, Destructible, Comparable
  end # ElementType
  # :nodoc:
  def new_element_type(type)
    ElementType.new(type)
  end
  private
  # :nodoc:
  def construct_stmt(values, from, to)
    if element.ctor?
      %${
        size_t index;
        for(index = #{from}; index <= #{to}; ++index) #{values}[index] = #{element.assign(element.ctor())};
      }$
    end
  end
  # :nodoc:
  def destruct_stmt(values, from, to)
    if element.dtor?
      %${
        size_t index;
        for(index = #{from}; index <= #{to}; ++index) #{element.dtor(values+"[index]")};
      }$
    end
  end
end # Vector


=begin rdoc
Data structure representing singly-linked list.
=end
class List < Structure
  # :nodoc:
  def write_exported_types(stream)
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
    $
  end
  # :nodoc:
  def write_exported_declarations(stream, declare, define)
    stream << %$
      #{declare} void #{ctor}(#{type}*);
      #{declare} void #{dtor}(#{type}*);
      #{declare} void #{purge}(#{type}*);
      #{declare} #{type}* #{new}(void);
      #{declare} void #{destroy}(#{type}*);
      #{declare} #{type}* #{assign}(#{type}*);
      #{declare} #{element.type} #{get}(#{type}*);
      #{declare} void #{add}(#{type}*, #{element.type});
      #{declare} void #{chop}(#{type}*);
      #{declare} int #{contains}(#{type}*, #{element.type});
      #{declare} #{element.type} #{find}(#{type}*, #{element.type});
      #{declare} int #{replace}(#{type}*, #{element.type}, #{element.type});
      #{declare} int #{replaceAll}(#{type}*, #{element.type}, #{element.type});
      #{declare} int #{remove}(#{type}*, #{element.type});
      #{declare} int #{removeAll}(#{type}*, #{element.type});
      #{declare} size_t #{size}(#{type}*);
      #{declare} int #{empty}(#{type}*);
      #{declare} void #{itCtor}(#{it}*, #{type}*);
      #{declare} int #{itHasNext}(#{it}*);
      #{declare} #{element.type} #{itNext}(#{it}*);
    $
  end
  # :nodoc:
  def write_implementations(stream, define)
    stream << %$
      #{define} void #{ctor}(#{type}* self) {
        #{assert}(self);
        self->head_node = NULL;
        self->node_count = 0;
      }
      #{define} void #{dtor}(#{type}* self) {
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
      #{define} #{type}* #{new}(void) {
        #{type}* self = (#{type}*)#{malloc}(sizeof(#{type})); #{assert}(self);
        #{ctor}(self);
        self->ref_count = 0;
        return self;
      }
      #{define} void #{destroy}(#{type}* self) {
        #{assert}(self);
        if(!--self->ref_count) {
          #{dtor}(self);
          #{free}(self);
        }
      }
      #{define} #{type}* #{assign}(#{type}* self) {
        ++self->ref_count;
        return self;
      }
      #{define} void #{purge}(#{type}* self) {
        #{dtor}(self);
        #{ctor}(self);
      }
      #{define} #{element.type} #{get}(#{type}* self) {
        #{assert}(self);
        #{assert}(!#{empty}(self));
        return self->head_node->element;
      }
      #{define} void #{chop}(#{type}* self) {
        #{node}* node;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        node = self->head_node;
        #{element.dtor("node->element")};
        self->head_node = self->head_node->next_node;
        --self->node_count;
        #{free}(node);
      }
      #{define} void #{add}(#{type}* self, #{element.type} element) {
        #{node}* node;
        #{assert}(self);
        node = (#{node}*)#{malloc}(sizeof(#{node})); #{assert}(node);
        node->element = #{element.assign("element")};
        node->next_node = self->head_node;
        self->head_node = node;
        ++self->node_count;
      }
      #{define} int #{contains}(#{type}* self, #{element.type} what) {
        #{node}* node;
        #{assert}(self);
        what = #{element.assign("what")};
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{element.dtor("what")};
            return 1;
          }
          node = node->next_node;
        }
        #{element.dtor("what")};
        return 0;
      }
      #{define} #{element.type} #{find}(#{type}* self, #{element.type} what) {
        #{node}* node;
        #{assert}(self);
        what = #{element.assign("what")};
        #{assert}(#{contains}(self, what));
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{element.dtor("what")};
            return node->element;
          }
          node = node->next_node;
        }
        #{abort}();
      }
      #{define} int #{replace}(#{type}* self, #{element.type} what, #{element.type} with) {
        #{node}* node;
        #{assert}(self);
        what = #{element.assign("what")};
        with = #{element.assign("with")};
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
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
      #{define} int #{replaceAll}(#{type}* self, #{element.type} what, #{element.type} with) {
        #{node}* node;
        int count = 0;
        #{assert}(self);
        what = #{element.assign("what")};
        with = #{element.assign("with")};
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
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
      #{define} int #{remove}(#{type}* self, #{element.type} what) {
        #{node}* node;
        #{node}* prev_node;
        int found = 0;
        #{assert}(self);
        what = #{element.assign("what")};
        node = self->head_node;
        prev_node = NULL;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
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
      #{define} int #{removeAll}(#{type}* self, #{element.type} what) {
        #{node}* node;
        #{node}* prev_node;
        int count = 0;
        #{assert}(self);
        what = #{element.assign("what")};
        node = self->head_node;
        prev_node = NULL;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
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
      #{define} size_t #{size}(#{type}* self) {
        #{assert}(self);
        return self->node_count;
      }
      #{define} int #{empty}(#{type}* self) {
        #{assert}(self);
        return !self->node_count;
      }
      #{define} void #{itCtor}(#{it}* self, #{type}* list) {
        #{assert}(self);
        #{assert}(list);
        self->next_node = list->head_node;
      }
      #{define} int #{itHasNext}(#{it}* self) {
        #{assert}(self);
        return self->next_node != NULL;
      }
      #{define} #{element.type} #{itNext}(#{it}* self) {
        #{node}* node;
        #{assert}(self);
        node = self->next_node;
        self->next_node = self->next_node->next_node;
        return node->element;
      }
    $
  end
  protected
  # :nodoc:
  class ElementType < DataStructBuilder::Type
    include Assignable, Destructible, EqualityTestable
  end # ElementType
  # :nodoc:
  def new_element_type(hash)
    ElementType.new(hash)
  end
  private
  # :nodoc:
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


=begin rdoc
Data structure representing doubly-linked list.
=end
class Queue < Structure
  # :nodoc:
  def write_exported_types(stream)
    stream << %$
      typedef struct #{node} #{node};
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{node}* head_node;
        #{node}* tail_node;
        size_t node_count;
        size_t ref_count;
      };
      struct #{it} {
        #{node}* next_node;
        int forward;
      };
      struct #{node} {
        #{element.type} element;
        #{node}* prev_node;
        #{node}* next_node;
      };
    $
  end
  # :nodoc:
  def write_exported_declarations(stream, declare, define)
    stream << %$
      #{declare} void #{ctor}(#{type}*);
      #{declare} void #{dtor}(#{type}*);
      #{declare} void #{purge}(#{type}*);
      #{declare} #{type}* #{new}(void);
      #{declare} void #{destroy}(#{type}*);
      #{declare} #{type}* #{assign}(#{type}*);
      #{declare} #{element.type} #{head}(#{type}*);
      #{declare} #{element.type} #{tail}(#{type}*);
      #{declare} void #{append}(#{type}*, #{element.type});
      #{declare} void #{prepend}(#{type}*, #{element.type});
      #{declare} void #{chopHead}(#{type}*);
      #{declare} void #{chopTail}(#{type}*);
      #{declare} int #{contains}(#{type}*, #{element.type});
      #{declare} #{element.type} #{find}(#{type}*, #{element.type});
      #{declare} int #{replace}(#{type}*, #{element.type}, #{element.type});
      #{declare} int #{replaceAll}(#{type}*, #{element.type}, #{element.type});
      #{declare} int #{remove}(#{type}*, #{element.type});
      #{declare} int #{removeAll}(#{type}*, #{element.type});
      #{declare} size_t #{size}(#{type}*);
      #{declare} int #{empty}(#{type}*);
      #{declare} void #{itCtor}(#{it}*, #{type}*, int);
      #{declare} int #{itHasNext}(#{it}*);
      #{declare} #{element.type} #{itNext}(#{it}*);
    $
  end
  # :nodoc:
  def write_implementations(stream, define)
    stream << %$
      #{define} void #{ctor}(#{type}* self) {
        #{assert}(self);
        self->head_node = self->tail_node = NULL;
        self->node_count = 0;
      }
      #{define} void #{dtor}(#{type}* self) {
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
      #{define} #{type}* #{new}(void) {
        #{type}* self = (#{type}*)#{malloc}(sizeof(#{type})); #{assert}(self);
        #{ctor}(self);
        self->ref_count = 0;
        return self;
      }
      #{define} void #{destroy}(#{type}* self) {
        #{assert}(self);
        if(!--self->ref_count) {
          #{dtor}(self);
          #{free}(self);
        }
      }
      #{define} #{type}* #{assign}(#{type}* self) {
        ++self->ref_count;
        return self;
      }
      #{define} void #{purge}(#{type}* self) {
        #{dtor}(self);
        #{ctor}(self);
      }
      #{define} #{element.type} #{head}(#{type}* self) {
        #{assert}(self);
        #{assert}(!#{empty}(self));
        return self->head_node->element;
      }
      #{define} #{element.type} #{tail}(#{type}* self) {
        #{assert}(self);
        #{assert}(!#{empty}(self));
        return self->tail_node->element;
      }
      #{define} void #{chopHead}(#{type}* self) {
        #{node}* node;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        node = self->head_node;
        #{element.dtor("node->element")};
        self->head_node = self->head_node->next_node;
        self->head_node->prev_node = NULL;
        --self->node_count;
        #{free}(node);
      }
      #{define} void #{chopTail}(#{type}* self) {
        #{node}* node;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        node = self->tail_node;
        #{element.dtor("node->element")};
        self->tail_node = self->tail_node->prev_node;
        self->tail_node->next_node = NULL;
        --self->node_count;
        #{free}(node);
      }
      #{define} void #{append}(#{type}* self, #{element.type} element) {
        #{node}* node;
        #{assert}(self);
        node = (#{node}*)#{malloc}(sizeof(#{node})); #{assert}(node);
        node->element = #{element.assign("element")};
        if(#{empty}(self)) {
          node->prev_node = node->next_node = NULL;
          self->tail_node = self->head_node = node;
        } else {
          node->next_node = NULL;
          node->prev_node = self->tail_node;
          self->tail_node->next_node = node;
          self->tail_node = node;
        }
        ++self->node_count;
      }
      #{define} void #{prepend}(#{type}* self, #{element.type} element) {
        #{node}* node;
        #{assert}(self);
        node = (#{node}*)#{malloc}(sizeof(#{node})); #{assert}(node);
        node->element = #{element.assign("element")};
        if(#{empty}(self)) {
          node->prev_node = node->next_node = NULL;
          self->tail_node = self->head_node = node;
        } else {
          node->prev_node = NULL;
          node->next_node = self->head_node;
          self->head_node->prev_node = node;
          self->head_node = node;
        }
        ++self->node_count;
      }
      #{define} int #{contains}(#{type}* self, #{element.type} what) {
        #{node}* node;
        #{assert}(self);
        what = #{element.assign("what")};
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{element.dtor("what")};
            return 1;
          }
          node = node->next_node;
        }
        #{element.dtor("what")};
        return 0;
      }
      #{define} #{element.type} #{find}(#{type}* self, #{element.type} what) {
        #{node}* node;
        #{assert}(self);
        what = #{element.assign("what")};
        #{assert}(#{contains}(self, what));
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{element.dtor("what")};
            return node->element;
          }
          node = node->next_node;
        }
        #{abort}();
      }
      #{define} int #{replace}(#{type}* self, #{element.type} what, #{element.type} with) {
        #{node}* node;
        #{assert}(self);
        what = #{element.assign("what")};
        with = #{element.assign("with")};
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
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
      #{define} int #{replaceAll}(#{type}* self, #{element.type} what, #{element.type} with) {
        #{node}* node;
        int count = 0;
        #{assert}(self);
        what = #{element.assign("what")};
        with = #{element.assign("with")};
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
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
      #{define} int #{remove}(#{type}* self, #{element.type} what) {
        #{node}* node;
        int found = 0;
        #{assert}(self);
        what = #{element.assign("what")};
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{node} *prev = node->prev_node, *next = node->next_node;
            #{element.dtor("node->element")};
            if(prev && next) {
              prev->next_node = next;
              next->prev_node = prev;
            } else if(prev) {
              prev->next_node = NULL;
              self->tail_node = prev;
            } else {
              next->prev_node = NULL;
              self->head_node = next;
            }
            --self->node_count;
            #{free}(node);
            found = 1;
            break;
          }
          node = node->next_node;
        }
        #{element.dtor("what")};
        return found;
      }
      #{define} int #{removeAll}(#{type}* self, #{element.type} what) {
        #{node}* node;
        int count = 0;
        #{assert}(self);
        what = #{element.assign("what")};
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{node} *prev = node->prev_node, *next = node->next_node;
            #{element.dtor("node->element")};
            if(prev && next) {
              prev->next_node = next;
              next->prev_node = prev;
            } else if(prev) {
              prev->next_node = NULL;
              self->tail_node = prev;
            } else {
              next->prev_node = NULL;
              self->head_node = next;
            }
            --self->node_count;
            #{free}(node);
            ++count;
          }
          node = node->next_node;
        }
        #{element.dtor("what")};
        return count;
      }
      #{define} size_t #{size}(#{type}* self) {
        #{assert}(self);
        return self->node_count;
      }
      #{define} int #{empty}(#{type}* self) {
        #{assert}(self);
        return !self->node_count;
      }
      #{define} void #{itCtor}(#{it}* self, #{type}* list, int forward) {
        #{assert}(self);
        #{assert}(list);
        self->forward = forward;
        self->next_node = forward ? list->head_node : list->tail_node;
      }
      #{define} int #{itHasNext}(#{it}* self) {
        #{assert}(self);
        return self->next_node != NULL;
      }
      #{define} #{element.type} #{itNext}(#{it}* self) {
        #{node}* node;
        #{assert}(self);
        node = self->next_node;
        self->next_node = self->forward ? self->next_node->next_node : self->next_node->prev_node;
        return node->element;
      }
    $
  end
  protected
  # :nodoc:
  class ElementType < DataStructBuilder::Type
    include Assignable, Destructible, EqualityTestable
  end # ElementType
  # :nodoc:
  def new_element_type(hash)
    ElementType.new(hash)
  end
  private
  # :nodoc:
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
end # Queue


=begin rdoc
Data structure representing hashed set.
=end
class HashSet < Structure
  # :nodoc:
  def initialize(*args)
    super
    @list = new_list
  end
  # :nodoc:
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
        size_t ref_count;
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
      #{declare} #{type}* #{new}(void);
      #{declare} void #{destroy}(#{type}*);
      #{declare} #{type}* #{assign}(#{type}*);
      #{declare} void #{purge}(#{type}*);
      #{declare} void #{rehash}(#{type}*);
      #{declare} int #{contains}(#{type}*, #{element.type});
      #{declare} #{element.type} #{get}(#{type}*, #{element.type});
      #{declare} size_t #{size}(#{type}*);
      #{declare} int #{empty}(#{type}*);
      #{declare} int #{put}(#{type}*, #{element.type});
      #{declare} void #{replace}(#{type}*, #{element.type});
      #{declare} int #{remove}(#{type}*, #{element.type});
      #{declare} void #{not?}(#{type}*, #{type}*);
      #{declare} void #{and?}(#{type}*, #{type}*);
      #{declare} void #{or?}(#{type}*, #{type}*);
      #{declare} void #{xor?}(#{type}*, #{type}*);
      #{declare} void #{itCtor}(#{it}*, #{type}*);
      #{declare} int #{itHasNext}(#{it}*);
      #{declare} #{element.type} #{itNext}(#{it}*);
    $
    stream << %$#{declare} void #{dumpStats}(#{type}*, FILE*);$ if $debug
  end
  # :nodoc:
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
      #{define} #{type}* #{new}(void) {
        #{type}* self = (#{type}*)#{malloc}(sizeof(#{type})); #{assert}(self);
        #{ctor}(self);
        self->ref_count = 0;
        return self;
      }
      #{define} void #{destroy}(#{type}* self) {
        #{assert}(self);
        if(!--self->ref_count) {
          #{dtor}(self);
          #{free}(self);
        }
      }
      #{define} #{type}* #{assign}(#{type}* self) {
        ++self->ref_count;
        return self;
      }
      #{define} void #{purge}(#{type}* self) {
        #{assert}(self);
        #{dtor}(self);
        self->buckets = NULL;
        #{rehash}(self);
      }
      #{define} void #{rehash}(#{type}* self) {
        #{@list.type}* buckets;
        size_t i, bucket_count, size, fill;
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
        for(i = 0; i < bucket_count; ++i) {
          #{@list.ctor}(&buckets[i]);
        }
        if(self->buckets) {
          #{it} it;
          #{itCtor}(&it, self);
          while(#{itHasNext}(&it)) {
            #{@list.type}* bucket;
            #{element.type} element = #{itNext}(&it);
            bucket = &buckets[#{element.hash("element")} % bucket_count];
            #{@list.add}(bucket, element);
          }
          #{dtor}(self);
        }
        self->buckets = buckets;
        self->bucket_count = bucket_count;
        self->size = size;
      }
      #{define} int #{contains}(#{type}* self, #{element.type} element) {
        int result;
        #{assert}(self);
        element = #{element.assign("element")};
        result = #{@list.contains}(&self->buckets[#{element.hash("element")} % self->bucket_count], element);
        #{element.dtor("element")};
        return result;
      }
      #{define} #{element.type} #{get}(#{type}* self, #{element.type} element) {
        #{element.type} result;
        #{assert}(self);
        element = #{element.assign("element")};
        #{assert}(#{contains}(self, element));
        result = #{@list.find}(&self->buckets[#{element.hash("element")} % self->bucket_count], element);
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
      #{define} int #{put}(#{type}* self, #{element.type} element) {
        int contained = 1;
        #{@list.type}* bucket;
        #{assert}(self);
        element = #{element.assign("element")};
        bucket = &self->buckets[#{element.hash("element")} % self->bucket_count];
        if(!#{@list.contains}(bucket, element)) {
          #{@list.add}(bucket, element);
          ++self->size;
          contained = 0;
          #{rehash}(self);
        }
        #{element.dtor("element")};
        return contained;
      }
      #{define} void #{replace}(#{type}* self, #{element.type} element) {
        #{@list.type}* bucket;
        #{assert}(self);
        element = #{element.assign("element")};
        bucket = &self->buckets[#{element.hash("element")} % self->bucket_count];
        if(!#{@list.replace}(bucket, element, element)) {
          #{@list.add}(bucket, element);
          ++self->size;
          #{rehash}(self);
        }
        #{element.dtor("element")};
      }
      #{define} int #{remove}(#{type}* self, #{element.type} what) {
        int removed = 0;
        #{@list.type}* bucket;
        #{assert}(self);
        what = #{element.assign("what")};
        bucket = &self->buckets[#{element.hash("what")} % self->bucket_count];
        if(#{@list.remove}(bucket, what)) {
          --self->size;
          removed = 1;
          #{rehash}(self);
        }
        #{element.dtor("what")};
        return removed;
      }
      #{define} void #{not?}(#{type}* self, #{type}* other) {
        #{it} it;
        #{assert}(self);
        #{assert}(other);
        #{itCtor}(&it, other);
        while(#{itHasNext}(&it)) {
          #{remove}(self, #{itNext}(&it));
        }
        #{rehash}(self);
      }
      #{define} void #{or?}(#{type}* self, #{type}* other) {
        #{it} it;
        #{assert}(self);
        #{assert}(other);
        #{itCtor}(&it, other);
        while(#{itHasNext}(&it)) {
          #{put}(self, #{itNext}(&it));
        }
        #{rehash}(self);
      }
      #{define} void #{and?}(#{type}* self, #{type}* other) {
        #{it} it;
        #{type} set;
        #{assert}(self);
        #{assert}(other);
        #{ctor}(&set);
        #{itCtor}(&it, self);
        while(#{itHasNext}(&it)) {
          #{element.type} element = #{itNext}(&it);
          if(#{contains}(other, element)) #{put}(&set, element);
        }
        #{itCtor}(&it, other);
        while(#{itHasNext}(&it)) {
          #{element.type} element = #{itNext}(&it);
          if(#{contains}(self, element)) #{put}(&set, element);
        }
        #{dtor}(self);
        self->buckets = set.buckets;
        self->size = set.size;
        #{rehash}(self);
        /*#{dtor}(&set);*/
      }
      #{define} void #{xor?}(#{type}* self, #{type}* other) {
        #{it} it;
        #{type} set;
        #{assert}(self);
        #{assert}(other);
        #{ctor}(&set);
        #{itCtor}(&it, self);
        while(#{itHasNext}(&it)) {
          #{element.type} element = #{itNext}(&it);
          if(!#{contains}(other, element)) #{put}(&set, element);
        }
        #{itCtor}(&it, other);
        while(#{itHasNext}(&it)) {
          #{element.type} element = #{itNext}(&it);
          if(!#{contains}(self, element)) #{put}(&set, element);
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
    stream << %$
      #{define} void #{dumpStats}(#{type}* self, FILE* file) {
        size_t index, min_size, max_size;
        #{assert}(self);
        #{assert}(file);
        min_size = self->size;
        max_size = 0;
        fprintf(file, "element count = %d\\n", self->size);
        fprintf(file, "bucket count = %d\\n", self->bucket_count);
        for(index = 0; index < self->bucket_count; ++index) {
          size_t bucket_size = #{@list.size}(&self->buckets[index]);
          if(min_size > bucket_size) min_size = bucket_size;
          if(max_size < bucket_size) max_size = bucket_size;
          fprintf(file, "[%d] element count = %d (%.1f%%)\\n", index, bucket_size, (double)bucket_size*100/self->size);
        }
        fprintf(file, "element count = [%d ... %d]\\n", min_size, max_size);
      }
    $ if $debug
  end
  protected
  # :nodoc:
  class ElementType < DataStructBuilder::Type
    include Assignable, Destructible, Hashable, EqualityTestable
  end # ElementType
  # :nodoc:
  def new_element_type(hash)
    @element_hash = hash
    ElementType.new(hash)
  end
  # :nodoc:
  def new_list
    List.new("#{type}List", @element_hash)
  end
end # Set


=begin rdoc
Data structure representing hashed map.
=end
class HashMap < Code
  include Writers
  attr_reader :key, :value
  # :nodoc:
  def entities; [PrologueCode, @key.code, @value.code, @entry.code].compact end
  # :nodoc:
  def initialize(type, key_descriptor, value_descriptor, visibility = :public)
    super(type, visibility)
    @entry_hash = {:type=>entry, :hash=>entryHash, :equal=>entryEqual, :assign=>entryAssign, :dtor=>entryDtor}
    @entry = new_entry_type
    @entry_set = new_entry_set
    @key = new_key_type(key_descriptor)
    @value = new_value_type(value_descriptor)
    @self_hash = {:type=>"#{type}*", :assign=>assign, :ctor=>new, :dtor=>destroy}
  end
  # :nodoc:
  def [](symbol)
    @self_hash[symbol]
  end
  # :nodoc:
  def write_intf(stream)
    key.write_intf(stream)
    value.write_intf(stream)
    super
  end
  # :nodoc:
  def write_exported_types(stream)
    stream << %$
      typedef struct #{@entry.type} #{@entry.type};
      struct #{@entry.type} {
        #{key.type} key;
        #{value.type} value;
        int valid_value;
      };
    $
    @entry_set.write_exported_types(stream)
    stream << %$
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{@entry_set.type} entries;
        size_t ref_count;
      };
      struct #{it} {
        #{@entry_set.it} it;
      };
    $
  end
  # :nodoc:
  def write_exported_declarations(stream, declare, define)
    stream << %$
      #{declare} void #{ctor}(#{type}*);
      #{declare} void #{dtor}(#{type}*);
      #{declare} #{type}* #{new}(void);
      #{declare} void #{destroy}(#{type}*);
      #{declare} #{type}* #{assign}(#{type}*);
      #{declare} void #{purge}(#{type}*);
      #{declare} void #{rehash}(#{type}*);
      #{declare} size_t #{size}(#{type}*);
      #{declare} int #{empty}(#{type}*);
      #{declare} int #{containsKey}(#{type}*, #{key.type});
      #{declare} #{value.type} #{get}(#{type}*, #{key.type});
      #{declare} int #{put}(#{type}*, #{key.type}, #{value.type});
      #{declare} void #{replace}(#{type}*, #{key.type}, #{value.type});
      #{declare} int #{remove}(#{type}*, #{key.type});
      #{declare} void #{itCtor}(#{it}*, #{type}*);
      #{declare} int #{itHasNext}(#{it}*);
      #{declare} #{key.type} #{itNextKey}(#{it}*);
      #{declare} #{value.type} #{itNextValue}(#{it}*);
      #{declare} #{@entry.type} #{itNext}(#{it}*);
    $
    stream << %$#{declare} void #{dumpStats}(#{type}*, FILE*);$ if $debug

  end
  # :nodoc:
  def write_implementations(stream, define)
    stream << %$
      static #{@entry.type} #{entryKeyOnly}(#{key.type} key) {
        #{@entry.type} entry;
        entry.key = key;
        entry.valid_value = 0;
        return entry;
      }
      static #{@entry.type} #{entryKeyValue}(#{key.type} key, #{value.type} value) {
        #{@entry.type} entry;
        entry.key = key;
        entry.value = value;
        entry.valid_value = 1;
        return entry;
      }
      static size_t #{entryHash}(#{@entry.type} entry) {
        return #{key.hash("entry.key")};
      }
      static int #{entryEqual}(#{@entry.type} lt, #{@entry.type} rt) {
        return #{key.equal("lt.key", "rt.key")};
      }
      static #{@entry.type} #{entryAssign}(#{@entry.type} entry) {
        entry.key = #{key.assign("entry.key")};
        if(entry.valid_value) entry.value = #{value.assign("entry.value")};
        return entry;
      }
      static void #{entryDtor}(#{@entry.type} entry) {
        #{key.dtor("entry.key")};
        if(entry.valid_value) #{value.dtor("entry.value")};
      }
    $
    @entry_set.write_exported_declarations(stream, static, inline)
    @entry_set.write_implementations(stream, static)
    stream << %$
      #{define} void #{ctor}(#{type}* self) {
        #{assert}(self);
        #{@entry_set.ctor}(&self->entries);
      }
      #{define} void #{dtor}(#{type}* self) {
        #{assert}(self);
        #{@entry_set.dtor}(&self->entries);
      }
      #{define} #{type}* #{new}(void) {
        #{type}* self = (#{type}*)#{malloc}(sizeof(#{type})); #{assert}(self);
        #{ctor}(self);
        self->ref_count = 0;
        return self;
      }
      #{define} void #{destroy}(#{type}* self) {
        #{assert}(self);
        if(!--self->ref_count) {
          #{dtor}(self);
          #{free}(self);
        }
      }
      #{define} void #{rehash}(#{type}* self) {
        #{assert}(self);
        #{@entry_set.rehash}(&self->entries);
      }
      #{define} #{type}* #{assign}(#{type}* self) {
        #{assert}(self);
        ++self->ref_count;
        return self;
      }
      #{define} void #{purge}(#{type}* self) {
        #{assert}(self);
        #{@entry_set.purge}(&self->entries);
      }
      #{define} size_t #{size}(#{type}* self) {
        #{assert}(self);
        return #{@entry_set.size}(&self->entries);
      }
      #{define} int #{empty}(#{type}* self) {
        #{assert}(self);
        return #{@entry_set.empty}(&self->entries);
      }
      #{define} int #{containsKey}(#{type}* self, #{key.type} key) {
        int result;
        #{@entry.type} entry;
        #{assert}(self);
        entry = #{@entry.assign("#{entryKeyOnly}(key)")};
        result = #{@entry_set.contains}(&self->entries, entry);
        #{@entry.dtor("entry")};
        return result;
      }
      #{define} #{value.type} #{get}(#{type}* self, #{key.type} key) {
        #{value.type} result;
        #{@entry.type} entry;
        #{assert}(self);
        entry = #{@entry.assign("#{entryKeyOnly}(key)")};
        #{assert}(#{containsKey}(self, key));
        result = #{@entry_set.get}(&self->entries, entry).value;
        #{@entry.dtor("entry")};
        return result;
      }
      #{define} int #{put}(#{type}* self, #{key.type} key, #{value.type} value) {
        #{@entry.type} entry = #{@entry.assign("#{entryKeyValue}(key,value)")};
        #{assert}(self);
        if(!#{containsKey}(self, key)) {
          #{@entry_set.put}(&self->entries, entry);
          #{@entry.dtor("entry")};
          return 1;
        } else {
          #{@entry.dtor("entry")};
          return 0;
        }
      }
      #{define} void #{replace}(#{type}* self, #{key.type} key, #{value.type} value) {
        #{@entry.type} entry;
        #{assert}(self);
        entry = #{@entry.assign("#{entryKeyValue}(key,value)")};
        #{@entry_set.replace}(&self->entries, entry);
        #{@entry.dtor("entry")};
      }
      #{define} int #{remove}(#{type}* self, #{key.type} key) {
        int removed;
        #{@entry.type} entry;
        #{assert}(self);
        entry = #{@entry.assign("#{entryKeyOnly}(key)")};
        removed = #{@entry_set.remove}(&self->entries, entry);
        #{@entry.dtor("entry")};
        return removed;
      }
      #{define} void #{itCtor}(#{it}* self, #{type}* map) {
        #{assert}(self);
        #{assert}(map);
        #{@entry_set.itCtor}(&self->it, &map->entries);
      }
      #{define} int #{itHasNext}(#{it}* self) {
        #{assert}(self);
        return #{@entry_set.itHasNext}(&self->it);
      }
      #{define} #{key.type} #{itNextKey}(#{it}* self) {
        #{assert}(self);
        return #{@entry_set.itNext}(&self->it).key;
      }
      #{define} #{value.type} #{itNextValue}(#{it}* self) {
        #{assert}(self);
        return #{@entry_set.itNext}(&self->it).value;
      }
      #{define} #{@entry.type} #{itNext}(#{it}* self) {
        #{assert}(self);
        return #{@entry_set.itNext}(&self->it);
      }
    $
    stream << %$
      #{define} void #{dumpStats}(#{type}* self, FILE* file) {
        #{assert}(self);
        #{assert}(file);
        #{@entry_set.dumpStats}(&self->entries, file);
      }
    $ if $debug
  end
  protected
  # :nodoc:
  class EntryType < DataStructBuilder::Type
    include Assignable, Destructible, Hashable, EqualityTestable
  end # EntryType
  # :nodoc:
  class KeyType < DataStructBuilder::Type
    include Assignable, Destructible, Hashable, EqualityTestable
  end # KeyType
  # :nodoc:
  class ValueType < DataStructBuilder::Type
    include Assignable, Destructible
  end # ValueType
  # :nodoc:
  def new_entry_type
    EntryType.new(@entry_hash)
  end
  # :nodoc:
  def new_key_type(type)
    KeyType.new(type)
  end
  # :nodoc:
  def new_value_type(type)
    ValueType.new(type)
  end
  # :nodoc:
  def new_entry_set
    HashSet.new("#{type}Set", @entry_hash)
  end
end # Map


end # DataStructBuilder