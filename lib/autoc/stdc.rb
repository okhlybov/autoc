require 'set'
require 'autoc/type'
require 'autoc/module'


module AutoC

  # TODO

  module STDC

    class STDBOOL_H < Primitive
      def dependencies; SET end
      SET = Set[Code.interface %$
        #include <stdbool.h>
      $].freeze
    end

    class STDDEF_H < Primitive
      def dependencies; SET end
      SET = Set[Code.interface %$
        #include <stddef.h>
      $].freeze
    end

    class MATH_H < Primitive
      def dependencies; SET end
      SET = Set[Code.interface %$
        #include <math.h>
      $].freeze
    end

    class COMPLEX_H < Primitive
      def comparable?; false end
      def dependencies; SET end
      SET = Set[Code.interface %$
        #include <complex.h>
      $].freeze
    end

    BOOL = STDBOOL_H.new '_Bool'
    SIZE_T = STDDEF_H.new :size_t
    PTRDIFF_T = STDDEF_H.new :ptrdiff_t
    UINTPTR_T = STDDEF_H.new :uintptr_t
    INT = Primitive.new :int
    UNSIGNED = UNSIGNED_INT = Primitive.new :unsigned
    FLOAT = Primitive.new :float
    DOUBLE = Primitive.new :double
    FLOAT_T = MATH_H.new :float_t
    DOUBLE_T = MATH_H.new :double_t
    LONG_DOUBLE = Primitive.new 'long double'
    CHAR = Primitive.new :char
    COMPLEX = COMPLEX_H.new '_Complex'
    FLOAT_COMPLEX = COMPLEX_H.new 'float _Complex'
    DOUBLE_COMPLEX = COMPLEX_H.new 'double _Complex'
    LONG_DOUBLE_COMPLEX = COMPLEX_H.new 'long double _Complex'

  end # STDC


end # AutoC