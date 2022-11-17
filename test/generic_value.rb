# frozen_string_literal: true


require 'autoc/composite'


# Full-fledged value type equipped with dynamic memory management
# useful for testing & documentation purposes
class GenericValue < AutoC::Composite
  def initialize(type, visibility: :public) = super
  def composite_interface_declarations(stream)
    super
    stream << %{
      /**
        @brief #{description}
      */
      typedef struct {
        int* value;
      } #{type};
    }
  end
  private def configure
    super
    def_method :void, :set, { self: lvalue, value: :int }, instance: :custom_create do
      code %{
        #{default_create}(self);
        *self->value = value;
      }
    end
    def_method :int, :get, { self: const_rvalue } do
      code %{
        assert(self);
        return *self->value;
      }
    end
    default_create.code %{
      assert(self);
      self->value = #{memory.allocate('int')};
      *self->value = 0;
    }
    destroy.code %{
      assert(self);
      #{memory.free('self->value')};
    }
    copy.code %{
      assert(self);
      assert(source);
      #{default_create}(self);
      *self->value = *source->value;
    }
    equal.code %{
      assert(self);
      assert(other);
      return *self->value == *other->value;
    }
    compare.code %{
      assert(self);
      assert(other);
      return *self->value < *other->value ? -1 : (*self->value > *other->value ? +1 : 0);
    }
    hash_code.code %{
      assert(self);
      return *self->value;
    }
  end
end
