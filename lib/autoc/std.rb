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
      Primitive.new(x)
    end

    attr_reader :matcher

    def initialize(type, matcher: Regexp.new("^#{type}$"), header: nil)
      super(type)
      @matcher = matcher
      dependencies << header unless header.nil?
      @@types << self
    end

    def inspect = "#{signature} <#{self.class}>"

  end


  MATH_H = AutoC::SystemHeader.new 'math.h'
  STDDEF_H = AutoC::SystemHeader.new 'stddef.h'
  STDBOOL_H = AutoC::SystemHeader.new 'stdbool.h'
  COMPLEX_H = AutoC::SystemHeader.new 'complex.h'
  INTTYPES_H = AutoC::SystemHeader.new 'inttypes.h'


  BOOL = Primitive.new '_Bool', matcher: /^(bool|_Bool)$/, header: STDBOOL_H


  CHAR = Primitive.new 'char'
  SIGNED_CHAR = Primitive.new 'signed char', matcher: /^signed\s+char$/
  UNSIGNED_CHAR = Primitive.new 'unsigned char', matcher: /^unsigned\s+char$/


  SHORT = SIGNED_SHORT = SHORT_INT = SIGNED_SHORT_INT = Primitive.new 'short', matcher: /^(signed\s+)?short(\s+int)?$/
  UNSIGNED_SHORT = UNSIGNED_SHORT_INT = Primitive.new 'unsigned short', matcher: /^unsigned\s+short(\s+int)?$/


  INT = SIGNED = SIGNED_INT = Primitive.new 'int', matcher: /^(int|signed|signed\s+int)$/
  UNSIGNED = UNSIGNED_INT = Primitive.new 'unsigned', matcher: /^(unsigned|unsigned\s+int)$/


  LONG = SIGNED_LONG = LONG_INT = SIGNED_LONG_INT = Primitive.new 'long', matcher: /^(signed\s+)?long(\s+int)?$/
  UNSIGNED_LONG = UNSIGNED_LONG_INT = Primitive.new 'unsigned long', matcher: /^unsigned\s+long(\s+int)?$/


  LONG_LONG = SIGNED_LONG_LONG = LONG_LONG_INT = SIGNED_LONG_LONG_INT = Primitive.new 'long long', matcher: /^(signed\s+)?long\s+long(\s+int)?$/
  UNSIGNED_LONG_LONG = UNSIGNED_LONG_LONG_INT = Primitive.new 'unsigned long long', matcher: /^unsigned\s+long\s+long(\s+int)?$/


  SIZE_T = Primitive.new 'size_t', header: STDDEF_H
  PTRDIFF_T = Primitive.new 'ptrdiff_t', header: STDDEF_H
  UINTPTR_T = Primitive.new 'uintptr_t', header: STDDEF_H


  FLOAT = Primitive.new 'float'
  DOUBLE = Primitive.new 'double'
  LONG_DOUBLE = Primitive.new 'long double', matcher: /^long\s+double$/


  FLOAT_T = Primitive.new 'float_t', header: MATH_H
  DOUBLE_T = Primitive.new 'double_t', header: MATH_H


  COMPLEX = Primitive.new '_Complex', matcher: /^(complex|_Complex)$/, header: COMPLEX_H
  FLOAT_COMPLEX = Primitive.new 'float _Complex', matcher: /^float\s+(complex|_Complex)$/, header: COMPLEX_H
  DOUBLE_COMPLEX = Primitive.new 'double _Complex', matcher: /^double\s+(complex|_Complex)$/, header: COMPLEX_H
  LONG_DOUBLE_COMPLEX = Primitive.new 'long double _Complex', matcher: /^long\s+double\s+(complex|_Complex)$/, header: COMPLEX_H


  INTPTR_T = Primitive.new 'intptr_t', header: INTTYPES_H
  INTMAX_T = Primitive.new 'intmax_t', header: INTTYPES_H
  UINTMAX_T = Primitive.new 'uintmax_t', header: INTTYPES_H


  [8, 16, 32, 64].each do |bit|
    const_set((type = "int#{bit}_t").upcase, Primitive.new(type, header: INTTYPES_H))
    const_set((type = "uint#{bit}_t").upcase, Primitive.new(type, header: INTTYPES_H))
    const_set((type = "int_fast#{bit}_t").upcase, Primitive.new(type, header: INTTYPES_H))
    const_set((type = "uint_fast#{bit}_t").upcase, Primitive.new(type, header: INTTYPES_H))
    const_set((type = "int_least#{bit}_t").upcase, Primitive.new(type, header: INTTYPES_H))
    const_set((type = "uint_least#{bit}_t").upcase, Primitive.new(type, header: INTTYPES_H))
  end


end