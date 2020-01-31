require 'autoc/type'


module AutoC

  #
  class RC < CompositeType

    def initialize(value, prefix: nil)
      @value = Type.coerce(value)
      super("#{@value.type}*", prefix: (prefix.nil? ? @value.prefix : prefix), deps: [@value])
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
      i = 0; params = @value.create_params.collect {|p| "#{p.type} arg#{i+=1}"}.join(',')
      args = ['ps->value'] + (1..@value.create_params.size).collect {|i| "arg#{i}"}
      stream << %$
        typedef #{type} #{cR};
        typedef struct {
          #{@value.type} value;
          unsigned count;
        } #{s};
        #{inline} #{cR} #{new}(#{params}) {
          #{s}* ps = (#{s}*)malloc(sizeof(#{s})); assert(ps);
          #{@value.create(*args)};
          ps->count = 1;
          return (#{cR}*)ps;
        }
        #{inline} #{cR} #{ref}(#{cR} r) {
          assert(r);
          ++(#{s}*)r->count;
          return r;
        }
        #{inline} #{cR} #{unref}(#{cR} r) {
          assert(r);
          if(--(#{s}*)r->count == 0) {
            #{@value.destroy("*r") if @value.destructible?};
            free(r);
            return NULL;
          } else
            return r;
        }
      $
    end

  end # RC


end # AutoC