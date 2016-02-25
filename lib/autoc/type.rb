require "forwardable"
require "autoc/code"


module AutoC
  

# @private
class Dispatcher

  # @private
  class ParameterArray < Array
    def self.coerce(*params)
      out = []
      i = 0
      params.each do |t|
        i += 1
        out << (t.is_a?(Array) ? t.collect {|x| x.to_s} : [t.to_s, "_#{i}"])
      end
      self.new(out)
    end
    # Test for parameter list compatibility
    def ===(other) other.is_a?(ParameterArray) && types == other.types end
    def types; collect {|x| x.first} end
    def names; collect {|x| x.last} end
    def pass; names.join(',') end
    def declaration; types.join(',') end
    def definition; collect {|x| "#{x.first} #{x.last}"}.join(',') end
  end # ParameterArray

  # def call(*params)
  
  def dispatch(*params)
    if params.empty?
      self
    else
      params = [] if params.size == 1 && params.first.nil?
      call(*params)
    end
  end
 
end # Dispatcher


# @private
class Statement < Dispatcher
  
  attr_reader :parameters
  
  def initialize(params = [])
    @parameters = ParameterArray.coerce(*params)
  end
  
end # Statement


# @private
class Function < Dispatcher
  
  # @private
  class Signature

    attr_reader :parameters, :result

    def initialize(params = [], result = nil)
      @parameters = Dispatcher::ParameterArray.coerce(*params)
      @result = (result.nil? ? :void : result).to_s
    end

  end # Signature

  extend Forwardable
  
  def_delegators :@signature,
    :parameters, :result
  
  attr_reader :name, :signature
  
  def initialize(name, a = [], b = nil)
    @name = AutoC.c_id(name)
    @signature = a.is_a?(Signature) ? a : Signature.new(a, b)
  end
  
  def to_s; name end
  
  def call(*params)
    "#{name}(#{params.join(',')})"
  end

  def definition
    "#{result} #{name}(#{parameters.definition})"
  end
  
  def declaration
    "#{result} #{name}(#{parameters.declaration})"
  end
  
end # Function


class Type < Code
  
  # @private
  CommonCode = Class.new(Code) do
    def write_intf(stream)
      stream << %$
        #ifndef AUTOC_INLINE
          #if defined(_MSC_VER) || defined(__DMC__)
            #define AUTOC_INLINE AUTOC_STATIC __inline
          #elif defined(__LCC__)
            #define AUTOC_INLINE AUTOC_STATIC /* LCC rejects static __inline */
          #elif __STDC_VERSION__ >= 199901L
            #define AUTOC_INLINE  AUTOC_STATIC inline
          #else
            #define AUTOC_INLINE AUTOC_STATIC
          #endif
        #endif
        #ifndef AUTOC_EXTERN
          #ifdef __cplusplus
            #define AUTOC_EXTERN extern "C"
          #else
            #define AUTOC_EXTERN extern
          #endif
        #endif
        #ifndef AUTOC_STATIC
          #if defined(_MSC_VER)
            #define AUTOC_STATIC __pragma(warning(suppress:4100)) static
          #elif defined(__GNUC__)
            #define AUTOC_STATIC __attribute__((__used__)) static
          #else
            #define AUTOC_STATIC static
          #endif
        #endif
        #include <stddef.h>
        #include <stdlib.h>
        #include <assert.h>
      $
    end
    def write_decls(stream)
      stream << %$
        #include <limits.h>
        #define AUTOC_MIN(a,b) ((a) > (b) ? (b) : (a))
        #define AUTOC_MAX(a,b) ((a) > (b) ? (a) : (b))
        #define AUTOC_RCYCLE(x) (((x) << 1) | ((x) >> (sizeof(x)*CHAR_BIT - 1))) /* NOTE : valid for unsigned types only */
      $
    end
  end.new

  def self.coerce(type)
    type.is_a?(Type) ? type : UserDefinedType.new(type)
  end
  
  def hash; self.class.hash ^ type.hash end
  
  def ==(other) self.class == other.class && type == other.type end
  
  alias :eql? :==
  
  def entities; super << CommonCode end

  attr_reader :type, :type_ref
  
  def prefix
    # Lazy evaluator for simple types like char* which do not actually use
    # this method and hence do not require the prefix to be a valid C identifier
    AutoC.c_id(type)
  end
  
  def initialize(type, visibility = :public)
    @type = type.to_s
    @type_ref = "#{self.type}*"
    @visibility = [:public, :private, :static].include?(visibility) ? visibility : raise("unsupported visibility")
    # Canonic special method signatures
    @signature = {
      :ctor => Function::Signature.new([type^:self]),
      :dtor => Function::Signature.new([type^:self]),
      :copy => Function::Signature.new([type^:dst, type^:src]),
      :equal => Function::Signature.new([type^:lt, type^:rt], :int),
      :identify => Function::Signature.new([type^:self], :size_t),
      :less => Function::Signature.new([type^:lt, type^:rt], :int),
    }
  end
  
  def method_missing(method, *args)
    str = method.to_s
    str = str.sub(/[\!\?]$/, '') # Strip trailing ? or !
    x = false # Have leading underscore
    if /_(.*)/ =~ str
      str = $1
      x = true
    end
    fn = prefix + str[0,1].capitalize + str[1..-1] # Ruby 1.8 compatible
    fn = "_" << fn if x # Carry over the leading underscore
    if args.empty?
      fn # Emit bare function name
    elsif args.size == 1 && args.first == nil
      fn + '()' # Use sole nil argument to emit function call with no arguments
    else
      fn + '(' + args.join(',') + ')' # Emit normal function call with supplied arguments
    end
  end
  
  def write_intf(stream)
    if public?
      write_intf_types(stream)
      write_intf_decls(stream, extern, inline)
    end
  end
  
  def write_decls(stream)
    if private?
      write_intf_types(stream)
      write_intf_decls(stream, extern, inline)
    elsif static?
      write_intf_types(stream)
      write_intf_decls(stream, static, inline)
    end
  end
  
  def write_defs(stream)
    if public? || private?
      write_impls(stream, nil)
    elsif static?
      write_impls(stream, static)
    end
  end
  
  # Abstract methods which must be defined in descendant classes
  
  # def write_intf_types(stream)
  
  # def write_intf_decls(stream, declare, define)
  
  # def write_impls(stream, define)
  
  def extern; :AUTOC_EXTERN end
  
  def inline; :AUTOC_INLINE end
  
  def static; :AUTOC_STATIC end
  
  def assert; :assert end
  
  def malloc; :malloc end
  
  def calloc; :calloc end
  
  def free; :free end
  
  def abort; :abort end
  
  def public?; @visibility == :public end
    
  def private?; @visibility == :private end
  
  def static?; @visibility == :static end

  # A generic type is not required to provide any special functions therefore all the
  # availability methods below return false
    
  # Returns *true* if the type provides a well-defined parameterless default type constructor
  def constructible?; false end

  # Returns *true* if the type provides a well-defined type constructor which can have extra arguments
  def initializable?; false end

  # Returns *true* if the type provides a well-defined type destructor
  def destructible?; false end

  # Returns *true* if the type provides a well-defined copy constructor to create a clone of an instance
  def copyable?; false end

  # Returns *true* if the type provides a well-defined equality test function
  def comparable?; false end
  
  # Returns *true* if the type provides a well-defined 'less than' test function
  def orderable?; false end

  # Returns *true* if the type provides a well-defined hash calculation function
  def hashable?; false end

  # Create forwarding readers which take arbitrary number of arguments
  [:ctor, :dtor, :copy, :equal, :identify, :less].each do |name|
    class_eval %$
      def #{name}(*args)
        @#{name}.dispatch(*args)
      end
    $
  end
  
end # Type


=begin

UserDefinedType represents a user-defined custom type.

=end
class UserDefinedType < Type
  
  # @private  
  class PublicDeclaration < Code
    def entities; super << Type::CommonCode end
    def initialize(forward) @forward = forward.to_s end
    def hash; @forward.hash end
    def ==(other) self.class == other.class && @forward == other.instance_variable_get(:@forward) end
    alias :eql? :==
    def write_intf(stream)
      stream << "\n#{@forward}\n"
    end
  end # PublicDeclaration

  def entities; super.concat(@deps) end
  
  def prefix; @prefix.nil? ? super : @prefix end
  
  def initialize(opt)
    opt = {:type => opt} if opt.is_a?(::Symbol) || opt.is_a?(::String)
    if opt.is_a?(Hash)
      t = opt[:type].nil? ? raise("type is not specified") : opt[:type].to_s
    else
      raise "argument must be a Symbol, String or Hash"
    end
    super(t)
    @prefix = AutoC.c_id(opt[:prefix]) unless opt[:prefix].nil?
    @deps = []; @deps << PublicDeclaration.new(opt[:forward]) unless opt[:forward].nil?
    define_callable(:ctor, opt) {def call(obj) "((#{obj}) = 0)" end}
    define_callable(:dtor, opt) {def call(obj) end}
    define_callable(:copy, opt) {def call(dst, src) "((#{dst}) = (#{src}))" end}
    define_callable(:equal, opt) {def call(lt, rt) "((#{lt}) == (#{rt}))" end}
    define_callable(:less, opt) {def call(lt, rt) "((#{lt}) < (#{rt}))" end}
    define_callable(:identify, opt) {def call(obj) "((size_t)(#{obj}))" end}
  end
  
  def constructible?; !@ctor.nil? && @ctor.parameters.size == 1 end

  def initializable?; !@ctor.nil? end

  def destructible?; !@dtor.nil? end

  def copyable?; !@copy.nil? end

  def comparable?; !@equal.nil? end

  def orderable?; !@less.nil? end

  def hashable?; !@identify.nil? end
    
  # The methods below are left empty as the user-defined types have no implementation on their own

  def write_intf_types(stream) end

  def write_intf_decls(stream, declare, define) end

  def write_impls(stream, define) end

  private
  
  # Default methods creator
  def define_callable(name, opt, &code)
    c = if opt.has_key?(name) && opt[name].nil?
      nil # Disable specific capability by explicitly setting the key to nil
    else
      signature = @signature[name]
      c = if opt[name].nil?
        # Implicit nil as returned by Hash#default method does synthesize statement block with default (canonic) parameter list
        Class.new(Statement, &code).new(signature.parameters)
      elsif opt[name].is_a?(Function)
        opt[name] # If a Function instance is given, pass it through
      else
        # If only a name is specified, assume it is the function name with default signature
        Function.new(opt[name], signature)
      end
    end
    instance_variable_set("@#{name}", c)
  end
  
end # UserDefinedType


=begin

Reference represents a managed counted reference for any type.
It can be used with any type, including AutoC collections themselves.

== Generated C interface

=== Type management

[cols="2*"]
|===
|*_Type_* * ~type~New(...)
|
Create and return a reference to *_Type_* with reference count set to one.

The storage for the returned instance is malloc()'ed. The instance is constructed with the type's constructor ~type~Ctor(...).

NOTE: The generated method borrows the second and subsequent arguments from the respective constructor.

|*_Type_* * ~type~Ref(*_Type_* * self)
|
Increment the +self+'s reference count and return +self+.

|*_void_* ~type~Free(*_Type_* * self)
|
Decrement the +self+'s reference count.
If the reference count reaches zero, free the storage and destroy the instance with the type's destructor ~type~Dtor().

=end
class Reference < Type
  
  extend Forwardable
  
  def_delegators :@target,
    :prefix,
    :public?, :private?, :static?,
    :constructible?, :initializable?, :destructible?, :comparable?, :orderable?, :hashable?

  # Return *true* since reference copying involves no call to the underlying type's copy constructor  
  def copyable?; true end
    
  attr_reader :target
    
  def initialize(target)
    @target = Type.coerce(target)
    super(@target.type_ref) # NOTE : the type of the Reference instance itself is actually a pointer type
    @init = Dispatcher::ParameterArray.new(@target.ctor.parameters[1..-1]) # Capture extra parameters from the target type constructor
    define_callable(:ctor, @init) {def call(obj, *params) "((#{obj}) = #{@ref.new?}(#{params.join(',')}))" end}
    define_callable(:dtor, [type]) {def call(obj) "#{@ref.free?}(#{obj})" end}
    define_callable(:copy, [type, type]) {def call(dst, src) "((#{dst}) = #{@ref.ref?}(#{src}))" end}
    define_callable(:equal, [type, type]) {def call(lt, rt) @target.equal("*#{lt}", "*#{rt}") end}
    define_callable(:less, [type, type]) {def call(lt, rt) @target.less("*#{lt}", "*#{rt}") end}
    define_callable(:identify, [type]) {def call(obj) @target.identify("*#{obj}") end}
  end
  
  def ==(other) @target == other.instance_variable_get(:@target) end
  
  alias :eql? :==
  
  def entities; super << @target end
  
  def write_intf_decls(stream, declare, define)
    stream << %$
      /***
      ****  <#{type}> (#{self.class})
      ***/
      #{declare} #{type} #{new?}(#{@init.declaration});
      #{declare} #{type} #{ref?}(#{type});
      #{declare} void #{free?}(#{type});
    $
  end
  
  def write_impls(stream, define)
    stream << %$
    #define AUTOC_COUNTER(p) (*(size_t*)((char*)(p) + sizeof(#{@target.type})))
      #{define} #{type} #{new?}(#{@init.definition}) {
        #{type} self = (#{type})#{malloc}(sizeof(#{@target.type}) + sizeof(size_t)); #{assert}(self);
        #{@target.ctor("*self", *@init.names)};
        AUTOC_COUNTER(self) = 1;
        return self;
      }
      #{define} #{type} #{ref?}(#{type} self) {
        #{assert}(self);
        ++AUTOC_COUNTER(self);
        return self;
      }
      #{define} void #{free?}(#{type} self) {
        #{assert}(self);
        if(--AUTOC_COUNTER(self) == 0) {
          #{@target.dtor("*self")};
          #{free}(self);
        }
      }
      #undef AUTOC_COUNTER
    $
  end
  
  private
  
  # @private
  class BoundStatement < Statement
    def initialize(ref, target, params)
      super(params)
      @ref = ref
      @target = target
    end
  end # BoundStatement
  
  def define_callable(name, param_types, &code)
    instance_variable_set("@#{name}", Class.new(BoundStatement, &code).new(self, @target, param_types))
  end
  
end # Reference


# @private
module Type::Redirecting

  # Setup special methods which receive types by reference instead of by value
  def initialize_redirectors
    define_redirector(:ctor, Function::Signature.new([type_ref^:self]))
    define_redirector(:dtor, Function::Signature.new([type_ref^:self]))
    define_redirector(:copy, Function::Signature.new([type_ref^:dst, type_ref^:src]))
    define_redirector(:equal, Function::Signature.new([type_ref^:lt, type_ref^:rt], :int))
    define_redirector(:identify, Function::Signature.new([type_ref^:self], :size_t))
    define_redirector(:less, Function::Signature.new([type_ref^:lt, type_ref^:rt], :int))
  end
  
  def write_redirectors(stream, declare, define)
    # Emit default redirection macros
    # Unlike other special methods the constructors may have extra arguments
    # Assume the constructor's first parameter is always a target
    ctor_ex = ctor.parameters.names[1..-1]
    ctor_lt = ["self"].concat(ctor_ex).join(',')
    ctor_rt = ["&self"].concat(ctor_ex).join(',')
    stream << %$
      #define _#{ctor}(#{ctor_lt}) #{ctor}(#{ctor_rt})
      #define _#{dtor}(self) #{dtor}(&self)
      #define _#{identify}(self) #{identify}(&self)
      #define _#{copy}(dst,src) #{copy}(&dst,&src)
      #define _#{equal}(lt,rt) #{equal}(&lt,&rt)
      #define _#{less}(lt,rt) #{less}(&lt,&rt)
    $
  end
  
private
      
  # @private
  class Redirector < Function
    # Redirect call to the specific macro
    def call(*params) "_#{name}(" + params.join(',') + ')' end
  end # Redirector
  
  def define_redirector(name, signature)
    instance_variable_set("@#{name}", Redirector.new(method_missing(name), signature))
  end
      
end # Redirecting


# Class adjustments for the function signature definition DSL
[::Symbol, ::String, Type].each do |type|
  type.class_eval do 
    def ^(name)
      [self, name]
    end
  end
end


end # AutoC