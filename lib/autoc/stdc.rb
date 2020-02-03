require 'set'
require 'autoc/type'
require 'autoc/module'


module AutoC

  # TODO

  module STDC

    class STDDEF_H < Primitive
      def dependencies; @@deps end
      @@deps = Set[Code.interface %$
        #include <stddef.h>
      $]
    end

    class COMPLEX_H < Primitive
      def orderable?; false end
      def dependencies; @@deps end
      @@deps = Set[Code.interface %$
        #include <complex.h>
      $]
    end

    SIZE_T = STDDEF_H.new :size_t
    PTRDIFF_T = STDDEF_H.new :ptrdiff_t
    INT = Primitive.new :int
    UNSIGNED = UNSIGNED_INT = Primitive.new :unsigned
    FLOAT = Primitive.new :float
    DOUBLE = Primitive.new :double
    CHAR = Primitive.new :char
    COMPLEX = COMPLEX_H.new :complex

  end # STDC


end # AutoC