# frozen_string_literal: true


require 'autoc/core'
require 'autoc/module'
require 'autoc/callable'


module AutoC


using self


def self.primitive(cls, **kws) = Type::Primitive.register(cls, **kws)


# Primitive C side type augmented with stdc library support
# This code performs type coercion for known standard C types
class Type::Primitive < Type

  include Entity

  @@cache = []

  def self.[](type)
    @@cache.each { |matcher, t| return t unless (matcher =~ type.to_s).nil? }
    Type::Primitive.new(type)
  end

  def self.register(cls, matcher: nil, dependencies: [], **kws)
    t = cls.is_a?(Type::Primitive) ? cls : Type::Primitive.new(cls, **kws)
    t.dependencies.merge(Array(dependencies))
    @@cache << [matcher.nil? ? Regexp.new("^#{cls}$") : matcher, t]
    t
  end

  def ==(other) = self.class == other.class && name_c == other.name_c

  alias eql? ==

  def hash = name_c.hash

  def to_in(name) = Variable.new(self, name)
  def to_out(name) = Variable.new(to_i, name)
  def to_inout(name) = Variable.new(to_i, name)

  ### Default initializer

  class Create < Callable
    def initialize(type) = super(nil, { target: (type) })
    def call(*arguments) = Call.new(self, arguments)
    class Call < Callable::Call
      def to_s = "#{arguments.first.lvalue_c} = 0"
    end
  end

  def default_create = @default_create ||= Create.new(self)

  ### Copy constructor (cloner)

  class Copy < Callable
    def initialize(type) = super(nil, { target: (type), source: type })
    def call(*arguments) = Call.new(self, arguments)
    class Call < Callable::Call
      def to_s = "#{arguments.first.lvalue_c} = #{arguments.last.rvalue_c}"
    end
  end

  def copy = @copy ||= Copy.new(self)

  ### Equality tester

  class Equal < Callable
    def initialize(type) = super(:int, { lt: type, rt: type })
    def call(*arguments) = Call.new(self, arguments)
    class Call < Callable::Call
      def to_s = "#{arguments.first.rvalue_c} == #{arguments.last.rvalue_c}"
    end
  end

  def equal = @equal ||= Equal.new(self)

  ### Ordering <=> tester

  class Compare < Callable
    def initialize(type) = super(:int, { lt: type, rt: type })
    def call(*arguments) = Call.new(self, arguments)
    class Call < Callable::Call
      def to_s
        lt = arguments.first.rvalue_c
        rt = arguments.last.rvalue_c
        "(#{lt} == #{rt} ? 0 : (#{lt} < #{rt} ? -1 : +1))"
      end
    end
  end

  def compare = @compare ||= Compare.new(self)

  ### Hash code computer

  class HashCode < Callable
    def initialize(type) = super(SIZE_T, { source: type })
    def call(*arguments) = Call.new(self, arguments)
    class Call < Callable::Call
      def to_s = "(size_t)(#{arguments.first.rvalue_c})"
    end
  end

  def hash_code = @hash_code ||= HashCode.new(self)

end


class Type::Indirection < Type

  include Entity

  attr_reader :type

  attr_reader :i

  def initialize(type, i = 1)
    super((@type = type.to_type).name_c + '*'*i)
    @i = i
  end

  def to_i(i = 1) = Indirection.new(type, self.i+i).to_type

  def to_type = @i == 0 ? type : self

end



MATH_H = SystemHeader.new 'math.h'
LIMITS_H = SystemHeader.new 'limits.h'
ASSERT_H = SystemHeader.new 'assert.h'
STDIO_H = SystemHeader.new 'stdio.h'
STDDEF_H = SystemHeader.new 'stddef.h'
MALLOC_H = SystemHeader.new 'malloc.h'
STRING_H = SystemHeader.new 'string.h'
STDBOOL_H = SystemHeader.new 'stdbool.h'
COMPLEX_H = SystemHeader.new 'complex.h'
INTTYPES_H = SystemHeader.new 'inttypes.h'


# Required by Visual Studio's rand_s() to work
STDLIB_H = Code.new interface: %{
  #define _CRT_RAND_S
  #include <stdlib.h>
}
BOOL = primitive '_Bool', matcher: /^(bool|_Bool)$/, dependencies: STDBOOL_H

CHAR = primitive 'char'
SIGNED_CHAR = primitive 'signed char', matcher: /^signed\s+char$/
UNSIGNED_CHAR = primitive 'unsigned char', matcher: /^unsigned\s+char$/


WCHAR_T = primitive 'wchar_t', dependencies: STDDEF_H


SHORT = SIGNED_SHORT = SHORT_INT = SIGNED_SHORT_INT = primitive 'short', matcher: /^(signed\s+)?short(\s+int)?$/
UNSIGNED_SHORT = UNSIGNED_SHORT_INT = primitive 'unsigned short', matcher: /^unsigned\s+short(\s+int)?$/


INT = SIGNED = SIGNED_INT = primitive 'int', matcher: /^(int|signed|signed\s+int)$/
UNSIGNED = UNSIGNED_INT = primitive 'unsigned', matcher: /^(unsigned|unsigned\s+int)$/


LONG = SIGNED_LONG = LONG_INT = SIGNED_LONG_INT = primitive 'long', matcher: /^(signed\s+)?long(\s+int)?$/
UNSIGNED_LONG = UNSIGNED_LONG_INT = primitive 'unsigned long', matcher: /^unsigned\s+long(\s+int)?$/


LONG_LONG = SIGNED_LONG_LONG = LONG_LONG_INT = SIGNED_LONG_LONG_INT = primitive 'long long', matcher: /^(signed\s+)?long\s+long(\s+int)?$/
UNSIGNED_LONG_LONG = UNSIGNED_LONG_LONG_INT = primitive 'unsigned long long', matcher: /^unsigned\s+long\s+long(\s+int)?$/


SIZE_T = primitive 'size_t', dependencies: STDDEF_H
PTRDIFF_T = primitive 'ptrdiff_t', dependencies: STDDEF_H
UINTPTR_T = primitive 'uintptr_t', dependencies: STDDEF_H


FLOAT = primitive 'float'
DOUBLE = primitive 'double'
LONG_DOUBLE = primitive 'long double', matcher: /^long\s+double$/


FLOAT_T = primitive 'float_t', dependencies: MATH_H
DOUBLE_T = primitive 'double_t', dependencies: MATH_H


TGMATH_H = SystemHeader.new 'tgmath.h'


class Type::Complex < Type::Primitive

  def initialize(*args, **kws)
    super(*args, **kws)
    dependencies << @@definitions
  end

  undef_method :compare

  def hash_code = @hash_code ||= HashCode.new(self)

  class HashCode < Primitive::HashCode

    def call(*arguments) = Call.new(self, arguments)

    class Call < Callable::Call
      def to_s = "(size_t)(creal(#{arguments.first})) ^ (size_t)(cimag(#{arguments.first}))"
    end

  end

  @@definitions = Code.new dependencies: [COMPLEX_H, TGMATH_H], interface: %{
    #ifdef __cplusplus
      using autoc_double_complex_t = std::complex<double>;
      using autoc_complex_t = autoc_double_complex_t;
      using autoc_float_complex_t = std::complex<float>;
      using autoc_long_double_complex_t = std::complex<long double>;
      using autoc_long_complex_t = autoc_long_double_complex_t;
    #else
      #if defined(_MSC_VER) && (!defined(__clang__) || !defined(__INTEL_COMPILER) || !defined(__INTEL_LLVM_COMPILER) || !defined(__POCC__))
        #error Visual Studio requires C++ compilation mode for complex numeric types
      #endif
      typedef float complex autoc_float_complex_t;
      typedef double complex autoc_double_complex_t;
      typedef autoc_double_complex_t autoc_complex_t;
      typedef long double complex autoc_long_double_complex_t;
      typedef autoc_long_double_complex_t autoc_long_complex_t;
    #endif
  }

end # Complex


LONG_DOUBLE_COMPLEX = primitive Type::Complex.new('autoc_long_double_complex_t'), matcher: /^long\s+double\s+(complex|_Complex)$/
DOUBLE_COMPLEX = primitive Type::Complex.new('autoc_double_complex_t'), matcher: /^double\s+(complex|_Complex)$/
FLOAT_COMPLEX = primitive Type::Complex.new('autoc_float_complex_t'), matcher: /^float\s+(complex|_Complex)$/
COMPLEX = primitive Type::Complex.new('autoc_complex_t'), matcher: /^(complex|_Complex)$/


INTPTR_T = primitive 'intptr_t', dependencies: INTTYPES_H
INTMAX_T = primitive 'intmax_t', dependencies: INTTYPES_H
UINTMAX_T = primitive 'uintmax_t', dependencies: INTTYPES_H


[8, 16, 32, 64].each do |bit|
  const_set((type = "int#{bit}_t").upcase, primitive(type, dependencies: INTTYPES_H))
  const_set((type = "uint#{bit}_t").upcase, primitive(type, dependencies: INTTYPES_H))
  const_set((type = "int_fast#{bit}_t").upcase, primitive(type, dependencies: INTTYPES_H))
  const_set((type = "uint_fast#{bit}_t").upcase, primitive(type, dependencies: INTTYPES_H))
  const_set((type = "int_least#{bit}_t").upcase, primitive(type, dependencies: INTTYPES_H))
  const_set((type = "uint_least#{bit}_t").upcase, primitive(type, dependencies: INTTYPES_H))
end


class << self
  remove_method :primitive
end


end
