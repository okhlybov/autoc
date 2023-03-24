# frozen_string_literal: true


require 'autoc/std'
require 'autoc/composite'


# Full-fledged value type equipped with dynamic memory management
# useful for testing & documentation purposes
class GenericValue < AutoC::Composite

  using AutoC::STD::Coercions

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

  def rvalue = @rv ||= AutoC::Value.new(self, reference: true)
  
  def lvalue = @lv ||= AutoC::Value.new(self, reference: true)
  
  def const_rvalue = @crv ||= AutoC::Value.new(self, constant: true)
  
  def const_lvalue = @clv ||= AutoC::Value.new(self, constant: true, reference: true)

private
  
  def configure
    super
    method(:void, :set, { target: lvalue, value: :int.const_rvalue }, instance: :custom_create, constraint:-> { custom_constructible? }).configure do
      code %{
        #{default_create.(target)};
        *target->value = value;
      }
    end
    method(:int, :get, { target: const_rvalue }).configure do
      code %{
        return *target.value;
      }
    end
    default_create.configure do
      code %{
        assert(target);
        target->value = #{memory.allocate('int')};
        *target->value = 0;
      }
    end
    destroy.configure do
        code %{
        assert(target);
        #{memory.free('target->value')};
      }
    end
    copy.configure do
      code %{
        assert(target);
        #{default_create}(target);
        *target->value = *source.value;
      }
    end
    equal.configure do
      code %{
        return *left.value == *right.value;
      }
    end
    compare.configure do
      code %{
        return *left.value < *right.value ? -1 : (*left.value > *right.value ? +1 : 0);
      }
    end
    hash_code.configure do
      code %{
        return *target.value;
      }
    end
  end

end
