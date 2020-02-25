require 'singleton'
require 'autoc/type'
require 'autoc/module'


module AutoC


  class Allocator

    include Singleton
    include Module::Entity

    def allocate(type, count = 1, zero = false)
      if zero
        "(#{type}*)calloc(#{count}, sizeof(#{type}))"
      else
        "(#{type}*)malloc((#{count})*sizeof(#{type}))"
      end
    end

    def free(ptr)
      "free(#{ptr})"
    end

    def interface(stream)
      stream << %$
        #include <malloc.h>
      $
    end

    @@default = instance
    def self.default; @@default end
    def self.default=(allocator) @@default = allocator end

  end # Allocator


  class Allocator::BDW

    include Singleton
    include Module::Entity

    def allocate(type, count = 1, zero = false)
      "(#{type}*)GC_malloc((#{count})*sizeof(#{type}))"
    end

    def free(ptr) end

    def interface(stream)
      stream << %$
        #include <gc.h>
      $
    end

  end # BDW


  module Reference

    def initialize(value, prefix: nil)
      @value = Type.coerce(value)
      super(prefix.nil? ? @value.type : prefix, prefix, [@value, memory])
      raise TraitError, 'value must be constructible' unless @value.constructible?
    end

    def memory
      AutoC::Allocator.default
    end

    def create(value, *args)
      "(#{value}) = #{new(*args)}"
    end

    def create_params
      @value.create_params
    end

    def interface(stream)
      stream << %$
        #include <assert.h>
      $
    end

  end # Reference


  #
  class Reference::Unique < Composite

    include Reference

    def destroy(value)
      "(#{value}) = #{free(value)}"
    end

    def interface(stream)
      super
      stream << %$
        typedef #{@value.type}* #{_p};
        #{inline} #{_p} #{new}(#{@value.create_params_declare}) {
          #{_p} p = #{memory.allocate(@value.type)}; assert(p);
          #{@value.create(*(['*p'] + @value.create_params_pass_list))};
          return p;
        }
        #{inline} #{_p} #{free}(#{_p} p) {
          assert(p);
          #{@value.destroy('*p') if @value.destructible?};
          #{memory.free(:p)};
          return NULL;
        }
      $
    end

  end # Unique


  #
  class Reference::Counted < Composite

    include Reference

    def copy(value, origin)
      "(#{value}) = #{ref(origin)}"
    end

    def destroy(value)
      "(#{value}) = #{unref(value)}"
    end

    def equal(value, other)
      @value.equal("*#{value}", "*#{other}")
    end

    def less(value, other)
      @value.less("*#{value}", "*#{other}")
    end

    def identify(value)
      @value.identify("*#{value}")
    end

    def comparable?
      @value.comparable?
    end

    def hashable?
      @value.hashable?
    end

    def interface(stream)
      super
      stream << %$
        typedef #{@value.type}* #{_p};
        typedef struct {
          #{@value.type} value;
          unsigned count;
        } #{_s};
        #{inline} #{_p} #{new}(#{@value.create_params_declare}) {
          #{_s}* p = #{memory.allocate(_s)}; assert(p);
          #{@value.create(*(['p->value'] + @value.create_params_pass_list))};
          p->count = 1;
          return (#{_p})p;
        }
        #{inline} #{_p} #{ref}(#{_p} p) {
          assert(p);
          ++((#{_s}*)p)->count;
          return p;
        }
        #{inline} #{_p} #{unref}(#{_p} p) {
          assert(p);
          if(--((#{_s}*)p)->count == 0) {
            #{@value.destroy('*p') if @value.destructible?};
            #{memory.free(:p)};
            return NULL;
          } else
            return p;
        }
        #define #{free}(p) #{unref}(p)
      $
    end

  end # Counted


end # AutoC