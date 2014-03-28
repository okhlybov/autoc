require "autoc/code_builder"


module AutoC
  

# :nodoc:  
class PublicDeclaration < CodeBuilder::Code
  def initialize(forward) @forward = forward.to_s end
  def priority; CodeBuilder::Priority::MAX end
  def hash; @forward.hash end
  def eql?(other)
    @forward == other.instance_variable_get(:@forward)
  end
  def write_intf(stream)
    stream << "\n"
    stream << @forward
    stream << "\n"
  end
end # Forward


class Type < CodeBuilder::Code
  
  # :nodoc:  
  CommonCode = Class.new(CodeBuilder::Code) do
    def write_intf(stream)
      stream << %$
        #ifndef AUTOC_INLINE
          #if defined(_MSC_VER) || defined(__PGI)
            #define AUTOC_INLINE __inline static
          #elif __STDC_VERSION__ >= 199901L && !defined(__DMC__)
            #define AUTOC_INLINE inline static
          #else
            #define AUTOC_INLINE static
          #endif
        #endif
        #ifndef AUTOC_EXTERN
          #if defined(__cplusplus)
            #define AUTOC_EXTERN extern "C"
          #else
            #define AUTOC_EXTERN extern
          #endif
        #endif
        #include <stddef.h>
        #include <stdlib.h>
        #include <assert.h>
      $
    end
  end.new

  def self.coerce(obj)
    obj.is_a?(Type) ? obj : Type.new(obj)
  end
  
  attr_reader :type
  
  def entities; [CommonCode] + @deps end
  
  def initialize(opt)
    @deps = []
    @visibility = :public
    if [Symbol, String].include?(opt.class)
      @type = opt.to_s
    elsif opt.is_a?(Hash)
      @type = opt[:type].nil? ? raise("type is not specified") : opt[:type].to_s
      [:ctor, :dtor, :copy, :equal, :less, :identify].each do |key|
        instance_variable_set("@#{key}".to_sym, Type.cid(opt[key])) unless opt[key].nil?
      end
      @deps << PublicDeclaration.new(opt[:forward]) unless opt[:forward].nil?
      optv = opt[:visibility]
      @visibility = [:public, :private, :static].include?(optv) ? optv : raise("unsupported visibility") unless optv.nil?
    else
      raise "failed to decode the argument"
    end
  end
  
  def method_missing(method, *args)
    str = method.to_s.chomp("?")
    @type + str[0].capitalize + str[1..-1]
  end
  
  def ctor(obj)
    @ctor.nil? ? "#{obj} = 0" : "#{@ctor}(#{obj})"
  end
  
  def dtor(obj)
    @dtor.nil? ? "" : "#{@dtor}(#{obj})"
  end
  
  def copy(dst, src)
    @copy.nil? ? "#{dst} = #{src}" : "#{@copy}(#{dst}, #{src})"
  end
  
  def equal(lt, rt)
    @equal.nil? ? "#{lt} == #{rt}" : "#{@equal}(#{lt}, #{rt})"
  end
  
  def less(lt, rt)
    @less.nil? ? "#{lt} < #{rt}" : "#{@less}(#{lt}, #{rt})"
  end
  
  def identify(obj)
    @identify.nil? ? "(size_t)(#{obj})" : "#{@identify}(#{obj})"
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
  
  def static; "static" end
  
  def assert; "assert" end
  
  def malloc; "malloc" end
  
  def calloc; "calloc" end
  
  def free; "free" end
  
  def abort; "abort" end
  
end # Type


end # AutoC