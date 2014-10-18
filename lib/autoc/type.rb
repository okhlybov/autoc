require "set"
require "autoc/code"


module AutoC
  

# @private
class Signature
  
  attr_reader :arguments, :result
  
  def initialize(arguments = [], result = nil)
    i = 0
    @arguments = Arguments.new
    arguments.each do |t|
      i += 1
      @arguments << (t.is_a?(Array) ? t : [t, "_#{i}"])
    end
    @result = result.nil? ? :void : result
  end

  private

  # @private
  class Arguments < Array
    def passthrough
      self.collect {|x| x.last}.join(',')
    end
    def declaration
      self.collect {|x| x.first}.join(',')
    end
    def definition
      self.collect {|x| "#{x.first} #{x.last}"}.join(',')
    end
  end
  
end # Signature


# @private
class Dispatcher

  # def call(*args)
  
  def dispatch(*args)
    if args.empty?
      self
    else
      args = [] if args.size == 1 && args.first.nil?
      call(*args)
    end
  end

end


# @private
class Function < Dispatcher
  
  attr_reader :name, :signature
  
  def initialize(name, signature)
    @name = name.to_s
    @signature = signature
  end
  
  def to_s; name end
  
  def call(*args)
    "#{name}(#{args.join(',')})"
  end

  def definition
    "#{signature.result} #{name}(#{signature.arguments.definition})"
  end
  
  def declaration
    "#{signature.result} #{name}(#{signature.arguments.declaration})"
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
  
  @@caps = [:ctor, :dtor, :copy, :equal, :less, :identify]
  
  def hash; self.class.hash ^ type.hash end
  
  def ==(other)
    self.class == other.class && type == other.type
  end
  
  def entities; super << CommonCode end

  attr_reader :type, :type_ref
  
  def initialize(type, visibility = :public)
    @type = type.to_s
    @type_ref = "#{self.type}*"
    @visibility = [:public, :private, :static].include?(visibility) ? visibility : raise("unsupported visibility")
    @capability = Set.new(@@caps)
    @ctor = method(:ctor, [type_ref^:self])
    @dtor = method(:dtor, [type_ref^:self])
    @copy = method(:copy, [type_ref^:dst, type_ref^:src])
    @equal = method(:equal, [type_ref^:lt, type_ref^:rt], :int)
    @identify = method(:identify, [type_ref^:self], :size_t)
    @less = method(:less, [type_ref^:lt, type_ref^:rt], :int)
  end
  
  alias :prefix :type
  
  def method_missing(method, *args)
    str = method.to_s.sub(/[\!\?]$/, "") # Strip trailing ? or !
    func = prefix + str[0,1].capitalize + str[1..-1] # Ruby 1.8 compatible
    if args.empty?
      func # Emit bare function name
    elsif args.size == 1 && args.first == nil
      func + "()" # Use sole nil argument to emit function call with no arguments
    else
      func + "(" + args.join(",") + ")" # Emit normal function call with supplied arguments
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
  
  def write_intf_types(stream) end
  
  def write_intf_decls(stream, declare, define) end
  
  def write_impls(stream, define) end
  
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

  def constructible?; @capability.include?(:ctor) end
  
  def destructible?; @capability.include?(:dtor) end
  
  def copyable?; @capability.include?(:copy) end
  
  def comparable?; @capability.include?(:equal) end

  def orderable?; comparable? && @capability.include?(:less) end

  def hashable?; comparable? && @capability.include?(:identify) end

  # Create readers which take arbitrary number of arguments
  [:ctor, :dtor, :copy, :equal, :identify, :less].each do |name|
    define_method(name) do |*args|
      instance_variable_get("@#{name}".to_sym).dispatch(*args)
    end
  end
  
  private

  def method(name, params = [], result = nil)
    Function.new(method_missing(name), Signature.new(params, result))
  end
  
end # Type


class UserDefinedType < Type
  
  # @private  
  class PublicDeclaration < Code
    def entities; super << Type::CommonCode end
    def initialize(forward) @forward = forward.to_s end
    def hash; @forward.hash end
    def eql?(other) self.class == other.class && @forward == other.instance_variable_get(:@forward) end
    def write_intf(stream)
      stream << "\n"
      stream << @forward
      stream << "\n"
    end
  end # PublicDeclaration

  def entities; super.concat(@deps) end
  
  def initialize(opt)
    opt = {:type => opt} if opt.is_a?(Symbol) || opt.is_a?(String)
    if opt.is_a?(Hash)
      t = opt[:type].nil? ? raise("type is not specified") : opt[:type]
    else
      raise "argument must be a Symbol, String or Hash"
    end
    super(t)
    @deps = []; @deps << PublicDeclaration.new(opt[:forward]) unless opt[:forward].nil?
    define_callable(:ctor, opt) {def call(obj) "((#{obj}) = 0)" end}
    define_callable(:dtor, opt) {def call(obj) end}
    define_callable(:copy, opt) {def call(dst, src) "((#{dst}) = (#{src}))" end}
    define_callable(:equal, opt) {def call(lt, rt) "((#{lt}) == (#{rt}))" end}
    define_callable(:less, opt) {def call(lt, rt) "((#{lt}) < (#{rt}))" end}
    define_callable(:identify, opt) {def call(obj) "((size_t)(#{obj}))" end}
  end
  
  private
  
  # Default methods creator
  def define_callable(name, opt, &block)
    iv = "@#{name}".to_s
    c = if opt[name].nil?
      Class.new(Dispatcher, &block).new
    elsif opt[name].is_a?(Function)
      opt[name]
    else
      Function.new(opt[name], instance_variable_get(iv).signature)
    end
    instance_variable_set(iv, c)
  end
  
  end # UserDefinedType


require "forwardable"


class Reference < Type
  
  extend Forwardable
  
  def_delegators :@target,
    :prefix, :hash,
    :public?, :private?, :static?,
    :constructible?, :destructible?, :copyable?, :comparable?, :orderable?, :hashable?
  
  def initialize(target)
    @target = Type.coerce(target)
    super(@target.type_ref)
  end
  
  alias :eql? :==
  
  def ==(other)
    super && @target == other.instance_variable_get(:@target)
  end
  
  def entities; super << @target end
  
  def write_intf_decls(stream, declare, define)
    stream << %$
      /***
      ****  <#{type}> (#{self.class})
      ***/
      #{declare} #{type} #{new?}();
      #{declare} #{type} #{ref?}(#{type});
      #{declare} void #{free?}(#{type});
    $
  end
  
  def write_impls(stream, define)
    stream << %$
    #define AUTOC_COUNTER(p) (*(size_t*)((char*)(p) + sizeof(#{@target.type})))
      #{define} #{type} #{new?}() {
        #{type} self = (#{type})#{malloc}(sizeof(#{@target.type}) + sizeof(size_t)); #{assert}(self);
        #{@target.ctor("*self")};
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
  
  def ctor(obj)
    "((#{obj}) = #{new?}())";
  end
  
  def dtor(obj)
    "#{free?}(#{obj})"
  end
  
  def copy(dst, src)
    "((#{dst}) = #{ref?}(#{src}))"
  end
  
  def equal(lt, rt)
    @target.equal("*#{lt}", "*#{rt}")
  end
  
  def less(lt, rt)
    @target.less("*#{lt}", "*#{rt}")
  end
  
  def identify(obj)
    @target.identify("*#{obj}")
  end
  
end


# Class adjustments for the function signature definition DSL
[Symbol, String, Type].each do |c|
  c.class_eval do 
    def ^(name)
      [self, name]
    end
  end
end


end # AutoC