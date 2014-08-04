require "set"
require "autoc/code"


module AutoC
  

  class Function

  attr_reader :name, :args, :result
  
  def initialize(name, args = [], result = nil)
    # TODO test the C type/name conformance
    @name = name.to_s
    @result = (result.nil? ? :void : result).to_s
    @args = args.collect {|x| x.to_s}
  end
  
  def with(new_name)
    Method.new(new_name, args, result)
  end
  
  def to_s; name; end

  def args_dec
    args.join(",")
  end
  
  def args_def
    i = 0
    args.collect {|x| "#{x} arg#{i+=1}"}.join(",")
  end
  
  def args_call
    (1..args.size).collect {|i| "arg#{i}"}.join(",")
  end
  
  def declaration
    "#{result} #{name}(#{args_dec})"
  end
  
  def definition
    "#{result} #{name}(#{args_def})"
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
  
  attr_reader :type, :prefix
  
  def hash; self.class.hash ^ type.hash end
  
  def ==(other)
    self.class == other.class && type == other.type
  end
  
  def entities; super << CommonCode end

  def initialize(type, visibility = :public, prefix = nil)
    @type = type.to_s
    @prefix = prefix.nil? ? @type : prefix.to_s
    @visibility = [:public, :private, :static].include?(visibility) ? visibility : raise("unsupported visibility")
    @capability = Set.new(@@caps)
  end
  
  def prefix
    if @prefix.nil?
      @prefix = type.to_s
      raise "prefix must be a valid C identifier" unless @prefix =~ /^[a-zA-Z_]\w*$/
    end
    @prefix
  end
  
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

  def entities; super + @deps end
  
  def initialize(opt)
    @deps = []
    v = :public
    p = nil
    if [Symbol, String].include?(opt.class)
      t = opt
    elsif opt.is_a?(Hash)
      t = opt[:type].nil? ? raise("type is not specified") : opt[:type]
      @@caps.each do |key|
        instance_variable_set("@#{key}".to_sym, opt[key].to_s) unless opt[key].nil?
      end
      @deps << PublicDeclaration.new(opt[:forward]) unless opt[:forward].nil?
      optv = opt[:visibility]
      v = optv.nil? ? :public : optv
      p = opt[:prefix] # This handles nil case as well
    else
      raise "failed to decode the argument"
    end
    super(t, v, p.nil? ? t : p)
  end
  
  def ctor(obj)
    @ctor.nil? ? "((#{obj}) = 0)" : "#{@ctor}(#{obj})"
  end
  
  def dtor(obj)
    @dtor.nil? ? nil : "#{@dtor}(#{obj})"
  end
  
  def copy(dst, src)
    @copy.nil? ? "((#{dst}) = (#{src}))" : "#{@copy}(#{dst}, #{src})"
  end
  
  def equal(lt, rt)
    @equal.nil? ? "((#{lt}) == (#{rt}))" : "#{@equal}(#{lt}, #{rt})"
  end
  
  def less(lt, rt)
    @less.nil? ? "((#{lt}) < (#{rt}))" : "#{@less}(#{lt}, #{rt})"
  end
  
  def identify(obj)
    @identify.nil? ? "((size_t)(#{obj}))" : "#{@identify}(#{obj})"
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
    super("#{@target.type}*")
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


end # AutoC