# frozen_string_literal: true


require 'autoc/module'
require 'autoc/function'
require 'autoc/decorator'


module AutoC


using self


module Composable
  
  def self.included(cls)
    cls.extend(Ctor)
  end

  module Ctor
    def new(*args, **kws)
      obj = super(*args, **kws)
      obj.send(:configure)
      obj
    end
  end

  include Entity

  include Decorator

  class Constant < Variable
    def declaration_c = "const #{super}"
  end

  def to_in(name) = Constant.new(to_i, name)
  def to_out(name) = Variable.new(to_i, name)
  def to_inout(name) = Variable.new(to_i, name)

  private def method(result, name, parameters = {}, respond_to: nil, abstract: false, visibility: self.visibility, constraint: true)
    method = Function.new(result, decorate(name), parameters, visibility:, abstract:, constraint:)
    self.class.define_method((respond_to.nil? ? name : respond_to).to_s) { |*args, **kws| method }
    method.dependencies << self
    references << method
    method
  end

end


end