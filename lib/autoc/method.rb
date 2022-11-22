# frozen_string_literal: true


require 'autoc/function'


module AutoC

  
  class Method < Function

    attr_reader :type
  
    def initialize(type, name, *args, **kws)
      super(type.decorate_identifier(name), *args, **kws)
      @type = type
    end
  
    def method_missing(meth, *args) = type.send(meth, *args)
  
  end # Method
  

end