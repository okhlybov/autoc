# frozen_string_literal: true


require 'set'
require 'autoc/module'
require 'autoc/primitive'


# A collection of standard (mostly) primitive C types
module AutoC::STD


  # Refinement handle automatic conversion o recognized C side types represented by string or symbol
  module Coercions
    refine AutoC::Type.singleton_class do
      def coerce(x) = x.is_a?(AutoC::Type) ? x : Primitive.coerce(x)
    end
  end


  # Base class for a more elaborate primitive type directly includable into the module as a dependency
  class Primitive < AutoC::Primitive

    include AutoC::Entity

    @@types = ::Set.new

    def self.coerce(x)
      @@types.each { |t| return t unless (t.matcher =~ x).nil? }
      AutoC::Primitive.new(x)
    end

    attr_reader :matcher

    def initialize(type, matcher = Regexp.new("^#{type}$"))
      super(type)
      @matcher = matcher
      @@types << self
    end

  end


  class Primitive

    class Boolean < Primitive; end

    class STDBOOL_H < Boolean
      SET = ::Set[AutoC::SystemHeader.new 'stdbool.h']
      def dependencies = SET
    end

    class Integer < Primitive; end

    class Character < Integer; end

    class STDDEF_H < Integer
      SET = ::Set[AutoC::SystemHeader.new 'stddef.h']
      def dependencies = SET
    end

    class Real < Primitive; end

    class MATH_H < Real
      SET = ::Set[AutoC::SystemHeader.new 'math.h']
      def dependencies = SET
    end

    class Complex < Primitive
      SET = ::Set[AutoC::SystemHeader.new 'complex.h']
      def dependencies = SET
      def orderable? = false
    end

    class INTTYPES_H < Integer
      SET = ::Set[AutoC::SystemHeader.new 'inttypes.h']
      def dependencies = SET
    end

  end # Primitive


  BOOL = Primitive::STDBOOL_H.new '_Bool', /^(bool|_Bool)$/


  CHAR = Primitive::Character.new 'char'
  SIGNED_CHAR = Primitive::Character.new 'signed char', /^signed\s+char$/
  UNSIGNED_CHAR = Primitive::Character.new 'unsigned char', /^unsigned\s+char$/


  SHORT = SIGNED_SHORT = SHORT_INT = SIGNED_SHORT_INT = Primitive::Integer.new 'short', /^(signed\s+)?short(\s+int)?$/
  UNSIGNED_SHORT = UNSIGNED_SHORT_INT = Primitive::Integer.new 'unsigned short', /^unsigned\s+short(\s+int)?$/


  INT = SIGNED = SIGNED_INT = Primitive::Integer.new 'int', /^(int|signed|signed\s+int)$/
  UNSIGNED = UNSIGNED_INT = Primitive::Integer.new 'unsigned', /^(unsigned|unsigned\s+int)$/


  LONG = SIGNED_LONG = LONG_INT = SIGNED_LONG_INT = Primitive::Integer.new 'long', /^(signed\s+)?long(\s+int)?$/
  UNSIGNED_LONG = UNSIGNED_LONG_INT = Primitive::Integer.new 'unsigned long', /^unsigned\s+long(\s+int)?$/


  LONG_LONG = SIGNED_LONG_LONG = LONG_LONG_INT = SIGNED_LONG_LONG_INT = Primitive::Integer.new 'long long', /^(signed\s+)?long\s+long(\s+int)?$/
  UNSIGNED_LONG_LONG = UNSIGNED_LONG_LONG_INT = Primitive::Integer.new 'unsigned long long', /^unsigned\s+long\s+long(\s+int)?$/


  SIZE_T = Primitive::STDDEF_H.new 'size_t'
  PTRDIFF_T = Primitive::STDDEF_H.new 'ptrdiff_t'
  UINTPTR_T = Primitive::STDDEF_H.new 'uintptr_t'


  FLOAT = Primitive::Real.new 'float'
  DOUBLE = Primitive::Real.new 'double'
  LONG_DOUBLE = Primitive::Real.new 'long double', /^long\s+double$/


  FLOAT_T = Primitive::MATH_H.new 'float_t'
  DOUBLE_T = Primitive::MATH_H.new 'double_t'


  COMPLEX = Primitive::Complex.new '_Complex', /^(complex|_Complex)$/
  FLOAT_COMPLEX = Primitive::Complex.new 'float _Complex', /^float\s+(complex|_Complex)$/
  DOUBLE_COMPLEX = Primitive::Complex.new 'double _Complex', /^double\s+(complex|_Complex)$/
  LONG_DOUBLE_COMPLEX = Primitive::Complex.new 'long double _Complex', /^long\s+double\s+(complex|_Complex)$/


  INTPTR_T = Primitive::INTTYPES_H.new 'intptr_t'
  INTMAX_T = Primitive::INTTYPES_H.new 'intmax_t'
  UINTMAX_T = Primitive::INTTYPES_H.new 'uintmax_t'


  [8, 16, 32, 64].each do |bit|
    const_set((type = "int#{bit}_t").upcase, Primitive::INTTYPES_H.new(type))
    const_set((type = "uint#{bit}_t").upcase, Primitive::INTTYPES_H.new(type))
    const_set((type = "int_fast#{bit}_t").upcase, Primitive::INTTYPES_H.new(type))
    const_set((type = "uint_fast#{bit}_t").upcase, Primitive::INTTYPES_H.new(type))
    const_set((type = "int_least#{bit}_t").upcase, Primitive::INTTYPES_H.new(type))
    const_set((type = "uint_least#{bit}_t").upcase, Primitive::INTTYPES_H.new(type))
  end


end