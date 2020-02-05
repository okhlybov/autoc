require 'autoc/type'


module AutoC

  #
  class CR < Composite

    def initialize(value, prefix: nil)
      @value = Type.coerce(value)
      pfx = prefix.nil? ? @value.prefix : prefix
      super("#{pfx}CR", prefix: pfx, deps: [@value, CODE])
      # TODO type traits conformance tests
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

    def orderable?
      @value.orderable?
    end

    def hashable?
      @value.hashable?
    end

    def interface(stream)
      stream << %$
        typedef #{@value.type}* #{cR};
        typedef struct {
          #{@value.type} value;
          unsigned count;
        } #{s};
        #{inline} #{cR} #{new}(#{@value.create_params_declare}) {
          #{s}* ps = (#{s}*)malloc(sizeof(#{s})); assert(ps);
          #{@value.create(*(['ps->value'] + @value.create_params_pass_list))};
          ps->count = 1;
          return (#{cR})ps;
        }
        #{inline} #{cR} #{ref}(#{cR} cr) {
          assert(cr);
          ++((#{s}*)cr)->count;
          return cr;
        }
        #{inline} #{cR} #{unref}(#{cR} cr) {
          assert(cr);
          if(--((#{s}*)cr)->count == 0) {
            #{@value.destroy("*cr") if @value.destructible?};
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