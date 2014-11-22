require "set"
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
          #ifdef _MSC_VER
            #define AUTOC_INLINE __inline
          #elif __STDC_VERSION__ >= 199901L
            #define AUTOC_INLINE inline AUTOC_STATIC
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
          #ifdef _MSC_VER
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
    # this method and hence do not require the prefix to be valid C identifier
    AutoC.c_id(type)
  end
  
  def initialize(type, visibility = :public)
    @type = type.to_s
    @type_ref = "#{self.type}*"
    @visibility = [:public, :private, :static].include?(visibility) ? visibility : raise("unsupported visibility")
    @capability = Set[:constructible, :destructible, :copyable, :comparable, :hashable, :orderable] # Can be used to disable specific capabilities for a type
    # Canonic special method signatures
    @ctor_signature = Function::Signature.new([type^:self])
    @dtor_signature = Function::Signature.new([type^:self])
    @copy_signature = Function::Signature.new([type^:dst, type^:src])
    @equal_signature = Function::Signature.new([type^:lt, type^:rt], :int)
    @identify_signature = Function::Signature.new([type^:self], :size_t)
    @less_signature = Function::Signature.new([type^:lt, type^:rt], :int)
  end
  
  def method_missing(method, *args)
    str = method.to_s
    str = str.sub(/[\!\?]$/, '') # Strip trailing ? or !
    fn = prefix + str[0,1].capitalize + str[1..-1] # Ruby 1.8 compatible
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
  
  # def write_intf_types(stream)
  
  # def write_intf_decls(stream, declare, define)
  
  # def write_impls(stream, define)
  
  def extern; "AUTOC_EXTERN" end
  
  def inline; "AUTOC_INLINE" end
  
  def static; "AUTOC_STATIC" end
  
  def assert; "assert" end
  
  def malloc; "malloc" end
  
  def calloc; "calloc" end
  
  def free; "free" end
  
  def abort; "abort" end
  
  def public?; @visibility == :public end
    
  def private?; @visibility == :private end
  
  def static?; @visibility == :static end

  def constructible?; @capability.include?(:constructible) end

  def destructible?; @capability.include?(:destructible) end

  def copyable?; @capability.include?(:copyable) end

  def comparable?; @capability.include?(:comparable) end
  
  def orderable?; @capability.include?(:orderable) && comparable? end

  def hashable?; @capability.include?(:hashable) && comparable? end

  # Create forwarding readers which take arbitrary number of arguments
  [:ctor, :dtor, :copy, :equal, :identify, :less].each do |name|
    class_eval %$
      def #{name}(*args)
        @#{name}.dispatch(*args)
      end
    $
  end
  
  private

  def define_function(name, signature)
    Function.new(method_missing(name), signature)
  end
  
end # Type


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
    opt = {:type => opt} if opt.is_a?(Symbol) || opt.is_a?(String)
    if opt.is_a?(Hash)
      t = opt[:type].nil? ? raise("type is not specified") : opt[:type].to_s
    else
      raise "argument must be a Symbol, String or Hash"
    end
    super(t)
    @prefix = AutoC.c_id(opt[:prefix]) unless opt[:prefix].nil?
    @deps = []; @deps << PublicDeclaration.new(opt[:forward]) unless opt[:forward].nil?
    opt.default = :unset # This allows to use nil as a value to indicate that the specific method is not avaliable
    opt[:ctor].nil? ? @capability.subtract([:constructible]) : define_callable(:ctor, opt) {def call(obj) "((#{obj}) = 0)" end}
    opt[:dtor].nil? ? @capability.subtract([:destructible]) : define_callable(:dtor, opt) {def call(obj) end}
    opt[:copy].nil? ? @capability.subtract([:copyable]) : define_callable(:copy, opt) {def call(dst, src) "((#{dst}) = (#{src}))" end}
    opt[:equal].nil? ? @capability.subtract([:comparable]) : define_callable(:equal, opt) {def call(lt, rt) "((#{lt}) == (#{rt}))" end}
    opt[:less].nil? ? @capability.subtract([:orderable]) : define_callable(:less, opt) {def call(lt, rt) "((#{lt}) < (#{rt}))" end}
    opt[:identify].nil? ? @capability.subtract([:hashable]) : define_callable(:identify, opt) {def call(obj) "((size_t)(#{obj}))" end}
    # Handle specific requirements
    @capability.subtract([:constructible]) if @ctor.parameters.size > 1 # Constructible type must not have extra parameters besides self
  end
  
  private
  
  # Default methods creator
  def define_callable(name, opt, &code)
    iv = "@#{name}"
    ivs = "@#{name}_signature"
    c = if opt[name] == :unset
      # Synthesize statement block with default (canonic) parameter list
      Class.new(Statement, &code).new(instance_variable_get(ivs).parameters)
    elsif opt[name].is_a?(Function)
      opt[name] # If a Function instance is given, pass it through
    else
      # If only a name is specified, assume it is the function name with default signature
      Function.new(opt[name], instance_variable_get(ivs))
    end
    instance_variable_set(iv, c)
  end
  
end # UserDefinedType


class Reference < Type
  
  extend Forwardable
  
  def_delegators :@target,
    :prefix,
    :public?, :private?, :static?,
    :constructible?, :destructible?, :copyable?, :comparable?, :orderable?, :hashable?
  
  def initialize(target)
    @target = Type.coerce(target)
    super(@target.type_ref) # NOTE : the type of the Reference instance itself is actually a pointer type
    @ctor_params = Dispatcher::ParameterArray.new(@target.ctor.parameters[1..-1]) # Capture extra parameters from the target type constructor
    define_callable(:ctor, @ctor_params) {def call(obj, *params) "((#{obj}) = #{@ref.new?}(#{params.join(',')}))" end}
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
      #{declare} #{type} #{new?}(#{@ctor_params.declaration});
      #{declare} #{type} #{ref?}(#{type});
      #{declare} void #{free?}(#{type});
    $
  end
  
  def write_impls(stream, define)
    stream << %$
    #define AUTOC_COUNTER(p) (*(size_t*)((char*)(p) + sizeof(#{@target.type})))
      #{define} #{type} #{new?}(#{@ctor_params.definition}) {
        #{type} self = (#{type})#{malloc}(sizeof(#{@target.type}) + sizeof(size_t)); #{assert}(self);
        #{@target.ctor("*self", *@ctor_params.names)};
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
  
  def define_callable(name, params, &code)
    instance_variable_set("@#{name}", Class.new(BoundStatement, &code).new(self, @target, params))
  end
  
end # Reference


# Class adjustments for the function signature definition DSL
[Symbol, String, Type].each do |type|
  type.class_eval do 
    def ^(name)
      [self, name]
    end
  end
end


end # AutoC