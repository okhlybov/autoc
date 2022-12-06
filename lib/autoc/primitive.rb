# frozen_string_literal: true


require 'autoc/type'


module AutoC

  
  class Primitive < Type

    def default_create(value) = custom_create(value, 0)
  
    def custom_create(value, initial) = copy(value, initial)
  
    def copy(value, source) = "(#{value} = #{source})"
  
    def equal(lt, rt) = "(#{lt} == #{rt})"
  
    def compare(lt, rt) = "(#{lt} == #{rt} ? 0 : (#{lt} > #{rt} ? +1 : -1))"
  
    def hash_code(value) = "(size_t)(#{value})"
  
  end # Primitive
  

end