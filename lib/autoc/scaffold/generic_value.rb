# frozen_string_literal: true


require 'autoc/std'
require 'autoc/composite'


using AutoC::STD::Coercions


# Full-fledged value type equipped with dynamic memory management
# useful for testing & documentation purposes
class GenericValue < AutoC::Composite
  def initialize(type, visibility: :public) = super
  def render_interface(stream)
    super
    stream << %{
      /**
        @brief #{description}
      */
      typedef struct {
        int* value; /**< @private */
      } #{signature};
    }
  end
  private def configure
    super
    method(:void, :set, { target: lvalue, value: :int.const_rvalue }, instance: :custom_create).configure do
      code %{
        #{default_create.(target)};
        *self->value = value;
      }
    end
    method(:int, :get, { target: const_rvalue }).configure do
      code %{
        assert(self);
        return *self->value;
      }
    end
    default_create.configure do
      code %{
        assert(self);
        self->value = #{memory.allocate('int')};
        *self->value = 0;
      }
    end
    destroy.configure do
        code %{
        assert(self);
        #{memory.free('self->value')};
      }
    end
    copy.configure do
      code %{
        assert(self);
        assert(source);
        #{default_create}(self);
        *self->value = *source->value;
      }
    end
    equal.configure do
      code %{
        assert(self);
        assert(other);
        return *self->value == *other->value;
      }
    end
    compare.configure do
      code %{
        assert(self);
        assert(other);
        return *self->value < *other->value ? -1 : (*self->value > *other->value ? +1 : 0);
      }
    end
    hash_code.configure do
      code %{
        assert(self);
        return *self->value;
      }
    end
  end
end
