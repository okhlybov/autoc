# frozen_string_literal: true


require 'autoc/module'
require 'autoc/function'
require 'autoc/decorator'
require 'autoc/composable'


module AutoC


using self


class Composite < Type

  include Composable

  def prefix_c = name_c

  private def render_interface(stream)
    super
    render_type_declaration(stream)
  end

  # def render_type_declaration(stream)

  private def configure
    # TODO docs
    method(:void, :create, { target: out(self) }, respond_to: :default_create, constraint: -> { default_constructible? })
    method(:void, :destroy, { target: inout(self) }, constraint: -> { destructible? })
    method(:int, :equal, { lt: self, rt: self }, constraint: -> { comparable? })
    method(:int, :compare, { lt: self, rt: self }, constraint: -> { orderable? })
    method(:size_t, :hash, { target: self }, respond_to: :hash_code, constraint: -> { hashable? })
    method(:void, :copy, { target: out(self), source: self }, constraint: -> { copyable? })
  end

  def method_missing?(meth, *args, **kws) = decorate(meth)

end


end
