require "autoc/code"


module AutoC
  

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
  end.new

  attr_reader :type
  
  def entities; [CommonCode] end

  def initialize(type, visibility = :public)
    @type = type.to_s
    @visibility = [:public, :private, :static].include?(visibility) ? visibility : raise("unsupported visibility")
  end
  
  def method_missing(method, *args)
    str = method.to_s
    func = @type + str[0,1].capitalize + str[1..-1] # Ruby 1.8 compatible
    if args.empty?
      func # Emit bare function name
    elsif args.size == 1 && args.first == nil
      func + "()" # Use sole nil argument to emit function call with no arguments
    else
      func + "(" + args.join(", ") + ")" # Emit normal function call with supplied arguments
    end
  end
  
  def write_intf(stream)
    case @visibility
      when :public
        write_exported_types(stream)
        write_exported_declarations(stream, extern, inline)
    end
  end
  
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
  
  def write_defs(stream)
    case @visibility
      when :public, :private
        write_implementations(stream, nil)
      when :static
        write_implementations(stream, static)
    end
  end
  
  def write_exported_types(stream) end
  
  def write_exported_declarations(stream, declare, define) end
  
  def write_implementations(stream, define) end
  
  def extern; "AUTOC_EXTERN" end
  
  def inline; "AUTOC_INLINE" end
  
  def static; "AUTOC_STATIC" end
  
  def assert; "assert" end
  
  def malloc; "malloc" end
  
  def calloc; "calloc" end
  
  def free; "free" end
  
  def abort; "abort" end
  
end # Type


class UserDefinedType < Type
  
  # @private  
  class PublicDeclaration < Code
    def entities; super + [Type::CommonCode] end
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
    if [Symbol, String].include?(opt.class)
      t = opt
    elsif opt.is_a?(Hash)
      t = opt[:type].nil? ? raise("type is not specified") : opt[:type]
      [:ctor, :dtor, :copy, :equal, :less, :identify].each do |key|
        instance_variable_set("@#{key}".to_sym, opt[key].to_s) unless opt[key].nil?
      end
      @deps << PublicDeclaration.new(opt[:forward]) unless opt[:forward].nil?
      optv = opt[:visibility]
      v = optv.nil? ? :public : optv
    else
      raise "failed to decode the argument"
    end
    super(t, v)
  end
  
  def ctor(obj)
    @ctor.nil? ? "(#{obj} = 0)" : "#{@ctor}(#{obj})"
  end
  
  def dtor(obj)
    @dtor.nil? ? nil : "#{@dtor}(#{obj})"
  end
  
  def copy(dst, src)
    @copy.nil? ? "(#{dst} = #{src})" : "#{@copy}(#{dst}, #{src})"
  end
  
  def equal(lt, rt)
    @equal.nil? ? "(#{lt} == #{rt})" : "#{@equal}(#{lt}, #{rt})"
  end
  
  def less(lt, rt)
    @less.nil? ? "(#{lt} < #{rt})" : "#{@less}(#{lt}, #{rt})"
  end
  
  def identify(obj)
    @identify.nil? ? "(size_t)(#{obj})" : "#{@identify}(#{obj})"
  end
  
end # UserDefinedType


end # AutoC