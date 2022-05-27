# frozen_string_literal: true


require 'set'
require 'autoc/type'
require 'autoc/module'


module AutoC::STDC


  class SystemHeader < Code
    def initialize(header) = super(interface: "\n#include <#{header}>\n")
  end


  class Primitive < AutoC::Primitive

    @@types = ::Set.new

    def self.coerce(type)
      @@types.each do |t|
        return t unless (t.matcher =~ type).nil?
      end
      return AutoC::Primitive.new(type)
    end

    attr_reader :matcher

    def initialize(type, matcher = Regexp.new("^#{type}$"))
      super(type)
      @matcher = matcher
      @@types << self
    end

  end


  class Boolean < Primitive
  end


  class STDBOOL_H < Boolean
    SET = ::Set[SystemHeader.new 'stdbool.h']
    def dependencies = SET
  end


  BOOL = STDBOOL_H.new '_Bool', /^(bool|_Bool)$/


  class Integer < Primitive
  end


  CHAR = Integer.new 'char'
  SIGNED_CHAR = Integer.new 'signed char', /^signed\s+char$/
  UNSIGNED_CHAR = Integer.new 'unsigned char', /^unsigned\s+char$/


  SHORT = SIGNED_SHORT = SHORT_INT = SIGNED_SHORT_INT = Integer.new 'short', /^(signed\s+)?short(\s+int)?$/
  UNSIGNED_SHORT = UNSIGNED_SHORT_INT = Integer.new 'unsigned short', /^unsigned\s+short(\s+int)?$/


  INT = SIGNED = SIGNED_INT = Integer.new 'int', /^(int|signed|signed\s+int)$/
  UNSIGNED = UNSIGNED_INT = Integer.new 'unsigned', /^(unsigned|unsigned\s+int)$/


  LONG = SIGNED_LONG = LONG_INT = SIGNED_LONG_INT = Integer.new 'long', /^(signed\s+)?long(\s+int)?$/
  UNSIGNED_LONG = UNSIGNED_LONG_INT = Integer.new 'unsigned long', /^unsigned\s+long(\s+int)?$/


  LONG_LONG = SIGNED_LONG_LONG = LONG_LONG_INT = SIGNED_LONG_LONG_INT = Integer.new 'long long', /^(signed\s+)?long\s+long(\s+int)?$/
  UNSIGNED_LONG_LONG = UNSIGNED_LONG_LONG_INT = Integer.new 'unsigned long long', /^unsigned\s+long\s+long(\s+int)?$/


  class STDDEF_H < Integer
    SET = ::Set[SystemHeader.new 'stddef.h']
    def dependencies = SET
  end


  SIZE_T = STDDEF_H.new 'size_t'
  PTRDIFF_T = STDDEF_H.new 'ptrdiff_t'
  UINTPTR_T = STDDEF_H.new 'uintptr_t'


  class Real < Primitive
  end


  FLOAT = Real.new 'float'
  DOUBLE = Real.new 'double'
  LONG_DOUBLE = Real.new 'long double', /^long\s+double$/


  class MATH_H < Real
    SET = ::Set[SystemHeader.new 'math.h']
    def dependencies = SET
  end


  FLOAT_T = MATH_H.new 'float_t'
  DOUBLE_T = MATH_H.new 'double_t'


  class Complex < Primitive
    SET = ::Set[SystemHeader.new 'complex.h']
    def dependencies = SET
    def orderable? = false
  end


  COMPLEX = Complex.new '_Complex', /^(complex|_Complex)$/
  FLOAT_COMPLEX = Complex.new 'float _Complex', /^float\s+(complex|_Complex)$/
  DOUBLE_COMPLEX = Complex.new 'double _Complex', /^double\s+(complex|_Complex)$/
  LONG_DOUBLE_COMPLEX = Complex.new 'long double _Complex', /^long\s+double\s+(complex|_Complex)$/


  class INTTYPES_H < Integer
    SET = ::Set[SystemHeader.new 'inttypes.h']
    def dependencies = SET
  end


  INTPTR_T = INTTYPES_H.new 'intptr_t'
  INTMAX_T = INTTYPES_H.new 'intmax_t'
  UINTMAX_T = INTTYPES_H.new 'uintmax_t'


  [8, 16, 32, 64].each do |bit|
    const_set((type = "int#{bit}_t").upcase, INTTYPES_H.new(type))
    const_set((type = "uint#{bit}_t").upcase, INTTYPES_H.new(type))
    const_set((type = "int_fast#{bit}_t").upcase, INTTYPES_H.new(type))
    const_set((type = "uint_fast#{bit}_t").upcase, INTTYPES_H.new(type))
    const_set((type = "int_least#{bit}_t").upcase, INTTYPES_H.new(type))
    const_set((type = "uint_least#{bit}_t").upcase, INTTYPES_H.new(type))
  end


end