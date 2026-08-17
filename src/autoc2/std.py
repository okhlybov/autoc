import re
from autoc2.core import Primitive as _Primitive, Macro, _type_rxcache
from autoc.module import Entity, Code, SystemHeader


math_h = SystemHeader("math.h")
tgmath_h = SystemHeader("tgmath.h")
limits_h = SystemHeader("limits.h")
assert_h = SystemHeader("assert.h")
stdio_h = SystemHeader("stdio.h")
stddef_h = SystemHeader("stddef.h")
string_h = SystemHeader("string.h")
stdbool_h = SystemHeader("stdbool.h")
complex_h = SystemHeader("complex.h")
inttypes_h = SystemHeader("inttypes.h")


stdlib_h = Code(interface="""
  #ifdef _MSC_VER
    #define _CRT_RAND_S
  #endif
  #include <stdlib.h>
""")


# Class representing a primitive value which is integrated into the code module infrastructure
class Primitive(_Primitive, Entity):
  
  @classmethod
  def register(cls, name, matcher=None, dependencies=[]):
    obj = cls(name)
    obj.dependencies.update(dependencies)
    if matcher is None:
      matcher = f"^{name}$"
    _type_rxcache.append((re.compile(matcher), obj))
    return obj


bool = Primitive.register("_Bool", matcher=r"^(bool|_Bool)$", dependencies=[stdbool_h])

char = Primitive.register("char")
signed_char = Primitive.register("signed char", matcher=r"^signed\s+char$")
unsigned_char = Primitive.register("unsigned char", matcher=r"^unsigned\s+char$")

wchar_t = Primitive.register("wchar_t", dependencies=[stddef_h])

short = signed_short = short_int = signed_short_int = Primitive.register("short", matcher=r"^(signed\s+)?short(\s+int)?$")
unsigned_short = unsigned_short_int = Primitive.register("unsigned short", matcher=r"^unsigned\s+short(\s+int)?$")

int = signed = signed_int = Primitive.register("int", matcher=r"^(int|signed|signed\s+int)$")
unsigned = unsigned_int = Primitive.register("unsigned", matcher=r"^(unsigned|unsigned\s+int)$")

long = signed_long = long_int = signed_long_int = Primitive.register("long", matcher=r"^(signed\s+)?long(\s+int)?$")
unsigned_long = unsigned_long_int = Primitive.register("unsigned long", matcher=r"^unsigned\s+long(\s+int)?$")

long_long = signed_long_long = long_long_int = signed_long_long_int = Primitive.register("long long", matcher=r"^(signed\s+)?long\s+long(\s+int)?$")
unsigned_long_long = unsigned_long_long_int = Primitive.register("unsigned long long", matcher=r"^unsigned\s+long\s+long(\s+int)?$")

size_t = Primitive.register("size_t", dependencies=[stddef_h])
ptrdiff_t = Primitive.register("ptrdiff_t", dependencies=[stddef_h])
uintptr_t = Primitive.register("uintptr_t", dependencies=[stddef_h])

float = Primitive.register("float")
double = Primitive.register("double")
long_double = Primitive.register("long double", matcher=r"^long\s+double$")

float_t = Primitive.register("float_t", dependencies=[math_h])
double_t = Primitive.register("double_t", dependencies=[math_h])


#
class Complex(Primitive):
  
  def __init__(self, *args, **kws):
    super().__init__(*args, dependencies=[Complex._definitions], **kws)

  def __setup__(self):
    super().__setup__()
    self.hash = Macro.of(self.hash, lambda target: f"(size_t)(creal({target})) ^ (size_t)(cimag({target}))")
  
  @property
  def orderable(self):
    return False
  
  _definitions = Code(
    dependencies=[complex_h, tgmath_h],
    interface="""
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
    """
  )


long_double_complex = Complex.register("autoc_long_double_complex_t", matcher=r"^long\s+double\s+(complex|_Complex)$")
double_complex = Complex.register("autoc_double_complex_t", matcher=r"^double\s+(complex|_Complex)$")
float_complex = Complex.register("autoc_float_complex_t", matcher=r"^float\s+(complex|_Complex)$")
complex = Complex.register("autoc_complex_t", matcher=r"^(complex|_Complex)$")

intptr_t = Primitive.register("intptr_t", dependencies=[inttypes_h])
intmax_t = Primitive.register("intmax_t", dependencies=[inttypes_h])
uintmax_t = Primitive.register("uintmax_t", dependencies=[inttypes_h])

for bits in [8, 16, 32, 64]:
  for prefix in ["int", "uint", "int_fast", "uint_fast", "int_least", "uint_least"]:
    type_name = f"{prefix}{bits}_t"
    globals()[type_name] = Primitive.register(type_name, dependencies=[inttypes_h])


linkage = Code(interface="""
  #ifndef AUTOC_EXTERN
    #ifdef __cplusplus
      #define AUTOC_EXTERN extern "C"
    #else
      #define AUTOC_EXTERN extern
    #endif
  #endif
  #ifndef AUTOC_STATIC_INLINE
    #if defined(__cplusplus) || (defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L)
      #define AUTOC_STATIC_INLINE static inline
    #else
      #define AUTOC_STATIC_INLINE static
    #endif
  #endif
""")