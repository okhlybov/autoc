require 'autoc/type'


module AutoC

  #
  class CR < Composite

    def initialize(type, value)
      @value = Type.coerce(value)
      super(type, nil, [@value, CODE])
      raise TraitError, 'value must be constructible' unless @value.constructible?
    end

    def create(value, *args)
      "(#{value}) = #{new(*args)}"
    end

    def create_params
      @value.create_params
    end

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
      stream << %$
        typedef #{@value.type}* #{type};
        typedef struct {
          #{@value.type} value;
          unsigned count;
        } #{_s};
        #{inline} #{type} #{new}(#{@value.create_params_declare}) {
          #{_s}* ps = (#{_s}*)malloc(sizeof(#{_s})); assert(ps);
          #{@value.create(*(['ps->value'] + @value.create_params_pass_list))};
          ps->count = 1;
          return (#{type})ps;
        }
        #{inline} #{type} #{ref}(#{type} cr) {
          assert(cr);
          ++((#{_s}*)cr)->count;
          return cr;
        }
        #{inline} #{type} #{unref}(#{type} cr) {
          assert(cr);
          if(--((#{_s}*)cr)->count == 0) {
            #{@value.destroy('*cr') if @value.destructible?};
            free(cr);
            return NULL;
          } else
            return cr;
        }
      $
    end

    CODE = Code.interface %$
      #include <assert.h>
      #include <malloc.h>
    $

  end # CR


end # AutoC