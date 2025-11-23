# frozen_string_literal: true


require 'autoc/core'
require 'autoc/module'
require 'autoc/decorator'


module AutoC


class Composite

  include Entity

  include Decorator

  alias prefix_c name_c

  def self.new(*args, **kws, &block)
    obj = super # Implicitly calls #initialize
    obj.send(:configure)
    obj
  end

  def initialize(*args, **kws)
    super
    @methods = {}
  end

  def references = super + @methods.values # Methods most likely introduce strong dependency on it of their own and hence can not be listed in type's dependencies

  def method(result, name, parameters = {}, respond_to: nil, abstract: false)
    method = (respond_to.nil? ? name : respond_to).to_sym
    @methods[method] = Function.new(result, decorate(name), parameters, visibility:, abstract:)
  end

  private def render_interface(stream)
    super
    render_type_declaration(stream) unless internal?
  end

  private def render_forward_declarations(stream)
    super
    render_type_declaration(stream) if internal?
  end

  # def render_type_declaration(stream)

  private def configure
    method(:void, :create, { target: self.out }, respond_to: :default_create, abstract: true)
  end

end


end
