# frozen_string_literal: true


require 'autoc/std'
require 'autoc/module'
require 'autoc/primitive'


class CompositeValue < AutoC::STD::Primitive
  
  def orderable? = false

  def render_interface(stream)
    stream << %{
      typedef struct {
        int a;
        char b;
      } #{self};
    }
  end
end