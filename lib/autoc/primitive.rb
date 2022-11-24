# frozen_string_literal: true


require 'autoc/type'


module AutoC

  
  class Primitive < Type

    def self.coerce(x) = Primitive.new(x)
  
    def default_create(value) = custom_create(value, 0)
  
    def custom_create(value, initial) = copy(value, initial)
  
    def copy(value, source) = "(#{value} = #{source})"
  
    def equal(lt, rt) = "(#{lt} == #{rt})"
  
    def compare(lt, rt) = "(#{lt} == #{rt} ? 0 : (#{lt} > #{rt} ? +1 : -1))"
  
    def hash_code(value) = "(size_t)(#{value})"
  
    def rvalue = @rv ||= Value.new(self)
  
    def lvalue = @lv ||= Value.new(self, reference: true)
  
    def const_rvalue = @crv ||= Value.new(self, constant: true)
  
    def const_lvalue = @crv ||= Value.new(self, constant: true, reference: true)
  
  end # Primitive
  

end