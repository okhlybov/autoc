# frozen_string_literal: true


require 'autoc/module'
require 'autoc/primitive'


# A collection of standard (mostly) primitive C types
module AutoC::STD


  # @private
  module PrimitiveCoercions
    def to_type = Primitive.adopt(self)
    def to_value = to_type.to_value
    def lvalue = to_type.lvalue
    def rvalue = to_type.rvalue
    def const_lvalue = to_type.const_lvalue
    def const_rvalue = to_type.const_rvalue
    def ~@ = %{"#{self}"} # Return C side string literal
  end

  # Refinement handle automatic conversion o recognized C side types represented by string or symbol
  module Coercions
    refine ::Symbol do import_methods PrimitiveCoercions end
    refine ::String do import_methods PrimitiveCoercions end
  end


  # Base class for a more elaborate primitive type directly includable into the module as a dependency
  class Primitive < AutoC::Primitive

    include AutoC::Entity

    @@types = ::Set.new

    def self.adopt(x)
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

    def to_value = rvalue

    def rvalue = @rv ||= AutoC::Value.new(self)
  
    def lvalue = @lv ||= AutoC::Value.new(self, reference: true)
    
    def const_rvalue = @crv ||= AutoC::Value.new(self, constant: true)
    
    def const_lvalue = @clv ||= AutoC::Value.new(self, constant: true, reference: true)
  
  end


  MATH_H = AutoC::SystemHeader.new 'math.h'
  LIMITS_H = AutoC::SystemHeader.new 'limits.h'
  ASSERT_H = AutoC::SystemHeader.new 'assert.h'
  STDIO_H = AutoC::SystemHeader.new 'stdio.h'
  STDDEF_H = AutoC::SystemHeader.new 'stddef.h'
  MALLOC_H = AutoC::SystemHeader.new 'malloc.h'
  STRING_H = AutoC::SystemHeader.new 'string.h'
  STDBOOL_H = AutoC::SystemHeader.new 'stdbool.h'
  COMPLEX_H = AutoC::SystemHeader.new 'complex.h'
  INTTYPES_H = AutoC::SystemHeader.new 'inttypes.h'


  # STDLIB_H = AutoC::SystemHeader.new 'stdlib.h'
  # Required by Visual Studio's rand_s() to work
  STDLIB_H = AutoC::Code.new interface: %{
    #ifdef _MSC_VER
      #define _CRT_RAND_S
    #endif
    #include <stdlib.h>
  }

  BOOL = Primitive.new '_Bool', matcher: /^(bool|_Bool)$/, header: STDBOOL_H


  CHAR = Primitive.new 'char'
  SIGNED_CHAR = Primitive.new 'signed char', matcher: /^signed\s+char$/
  UNSIGNED_CHAR = Primitive.new 'unsigned char', matcher: /^unsigned\s+char$/

  
  WCHAR_T = Primitive.new 'wchar_t', header: STDDEF_H


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


  class Complex < Primitive
    def hash_code = @hash_code ||= -> (target) { "((size_t)(crealf(#{target}))^(size_t)(cimagf(#{target})))" } # TODO use tgmath
  end # Complex

  COMPLEX = Complex.new '_Complex', matcher: /^(complex|_Complex)$/, header: COMPLEX_H
  FLOAT_COMPLEX = Complex.new 'float _Complex', matcher: /^float\s+(complex|_Complex)$/, header: COMPLEX_H
  DOUBLE_COMPLEX = Complex.new 'double _Complex', matcher: /^double\s+(complex|_Complex)$/, header: COMPLEX_H
  LONG_DOUBLE_COMPLEX = Complex.new 'long double _Complex', matcher: /^long\s+double\s+(complex|_Complex)$/, header: COMPLEX_H


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


  STACK_ALLOCATE = AutoC::Code.new interface: %{
    #ifdef __has_builtin
      #if __has_builtin(__builtin_alloca)
        #define _AUTOC_ALLOCA __builtin_alloca
      #endif
    #elif defined(_MSC_VER)
      #define _AUTOC_ALLOCA _alloca
    #elif defined(HAVE_ALLOCA)
      #define _AUTOC_ALLOCA alloca
    #endif
    #if defined(_AUTOC_ALLOCA)
      #define _AUTOC_STACK_ALLOCATE(type, count) (type*)_AUTOC_ALLOCA(sizeof(type)*(count))
    #else
      #error missing any suitable implementation of alloca()
    #endif
  }
  STACK_ALLOCATE.dependencies << MALLOC_H


end