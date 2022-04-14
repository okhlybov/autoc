# frozen_string_literal: true


require 'autoc/type'


module AutoC


  class SystemHeader < Code
    def initialize(header) = super interface: "\n#include <#{header}>\n"
  end


  class STDDEF_H < Primitive
    def self.static = ::Set[@code]
    def dependencies = STDDEF_H.static
    @code = SystemHeader.new 'stddef.h'
  end


  class MATH_H < Primitive
    def self.static = ::Set[@code]
    def dependencies = MATH_H.static
    @code = SystemHeader.new 'math.h'
  end


  class COMPLEX_H < Primitive
    def self.static = ::Set[@code]
    def dependencies = COMPLEX_H.static
    @code = SystemHeader.new 'complex.h'
    def orderable? = false
  end


  SIZE_T = STDDEF_H.new 'size_t'
  PTRDIFF_T = STDDEF_H.new 'ptrdiff_t'
  UINTPTR_T = STDDEF_H.new 'uintptr_t'


  FLOAT_T = MATH_H.new 'float_t'
  DOUBLE_T = MATH_H.new 'double_t'


  COMPLEX = COMPLEX_H.new '_Complex'
  FLOAT_COMPLEX = COMPLEX_H.new 'float _Complex'
  DOUBLE_COMPLEX = COMPLEX_H.new 'double _Complex'
  LONG_DOUBLE_COMPLEX = COMPLEX_H.new 'long double _Complex'


end