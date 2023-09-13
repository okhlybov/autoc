# frozen_string_literal: true


require 'autoc/type'


module AutoC

  
  class Primitive < Type

    def default_create = @default_create ||= -> (target) { copy.(target, 0) }
  
    def custom_create = @custom_create ||= -> (target, source) { copy.(target, source) }
  
    def copy = @copy ||= -> (target, source) { "#{target} = #{source}" }
  
    def equal = @equal ||= -> (lt, rt) { "(#{lt} == #{rt})" }

    def compare = @compare ||= -> (lt, rt) { "(#{lt} == #{rt} ? 0 : (#{lt} > #{rt} ? +1 : -1))" }
  
    def hash_code = @hash_code ||= -> (target) { "(size_t)(#{target})" }
  
  end # Primitive
  

end