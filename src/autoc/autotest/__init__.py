# Programmatic concept-based test suite.
#
# Unlike the hand-crafted autoc.test package whose modules each spell out their
# units, this package derives its units from the generator's own type hierarchy:
# concept-test mixins (concepts.py) emit per-method/per-invariant units for every
# concrete container instantiation registered in the matrix (matrix.py) over a
# selection of element kinds (elements.py).
#
# The framework layer is a deliberate self-contained copy of the autoc.test one:
# a separate `codes` registry and a separate harness entity keep the two suites
# independent (each renders into its own module and executable) while preserving
# the familiar Unit/Type/setup/unit API.


import autoc.core
import autoc.module


codes = set()


autoc.core.decorator = autoc.core.snake_decorator


def _import_modules(package):
  import pkgutil
  import importlib
  for importer, module_name, is_pkg in pkgutil.walk_packages(package.__path__, package.__name__ + "."):
    importlib.import_module(module_name)


def configure_module(module):
  _import_modules(autoc.autotest)
  code = []
  code.append("void run_codes(void) {\n")
  for c in sorted(codes):
    module.add(c)
    code.append(f"run_code({c.name});\n")
  code.append("}")
  module.add(autoc.module.Code(definitions=str().join(code)))


# Method presence is three-valued: missing (no attribute), disabled (attribute
# is None) and trait-constrained (Callable whose constraint evaluates false).
# An operation is emittable when it exists, is enabled, is active and carries a
# body - abstract function prototypes would render declarations without
# definitions breaking the link.
def active(type, attribute):
  m = getattr(type, attribute, None)
  if m is None or not m.active:
    return False
  if hasattr(m, "abstract") and m.abstract:
    return False
  return True


class Unit(autoc.module.Code):

  def __init__(self, name, dependencies=[]):
    super().__init__(dependencies=[code, *dependencies])
    self.name = name
    codes.add(self)

  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    if header:
      stream.append(f"void {self.name}(void);")

  def render_definitions(self, stream, header):
    super().render_definitions(stream, header)
    if not header:
      stream.append(f"void {self.name}(void) {{\n")
      self.render_code(stream)
      stream.append(f"}}\n")

  def render_code(self, stream):
    stream.append("++run;\n")
    stream.append(self.code)


class Type(Unit):

  def __init__(self, type, dependencies=[], name=None):
    self.type = autoc.core._type(type)
    if name is None:
      name = self.type.name
    super().__init__(f"code_{name}", dependencies=[*dependencies, self.type])
    self._setup = str()
    self._cleanup = str()
    self.codes = []

  def render_code(self, stream):
    stream.append(rf'fprintf(stdout, "\n--- {self.type}\n");')
    for c in self.codes:
      stream.append(c)

  def setup(self, code):
    self._setup = code

  def cleanup(self, code):
    self._cleanup = code

  # The tag is rendered into a printf format string so it must not contain
  # double quotes or percent signs - compose tags from attribute names only
  # (str() of a Macro call site is "->", never interpolate callables here)
  def unit(self, tag, code):
    s = rf'fprintf(stdout, "    {str(tag)}\n")'
    self.codes.append(f"""
      {{
        ++run;
        {s};
        {self._setup}
        {code}
        {self._cleanup}
      }}
    """)


code = autoc.module.Code(
  interface=r"""
    #include <stdlib.h>
    #include <stdio.h>
    #include <string.h>
    #define TEST_MESSAGE(s) fprintf(stdout, "*** %s\\n", s); fflush(stdout);
    #define TEST_ASSERT(x) if(x) {} else condition_failure("evaluated to FALSE", #x, __FILE__, __LINE__)
    #define TEST_TRUE(x) if(x) {} else condition_failure("expected TRUE but got FALSE", #x, __FILE__, __LINE__)
    #define TEST_FALSE(x) if(x) condition_failure("expected FALSE but got TRUE", #x, __FILE__, __LINE__)
    #define TEST_NULL(x) if((x) == NULL) {} else condition_failure("expected NULL", #x, __FILE__, __LINE__)
    #define TEST_NOT_NULL(x) if((x) == NULL) condition_failure("expected not NULL", #x, __FILE__, __LINE__)
    #define TEST_EQUAL(x, y) if((x) == (y)) {} else equality_failure("expected equality", #x, #y, __FILE__, __LINE__)
    #define TEST_NOT_EQUAL(x, y) if((x) == (y)) equality_failure("expected non-equality", #x, #y, __FILE__, __LINE__)
    #define TEST_EQUAL_CHARS(x, y) if(strcmp(x, y) == 0) {} else equality_failure("expected strings equality", #x, #y, __FILE__, __LINE__)
    #define TEST_NOT_EQUAL_CHARS(x, y) if(strcmp(x, y) == 0) equality_failure("expected strings non-equality", #x, __FILE__, __LINE__)
    void condition_failure(const char* message, const char* condition, const char* file, int line);
    void equality_failure(const char* message, const char* x, const char* y, const char* file, int line);
    void run_code(void(*code)(void));
    void run_codes();
    extern int run, failed;
  """,
  implementation=r"""
    int failure;
    void condition_failure(const char* message, const char* condition, const char* file, int line) {
      fprintf(stdout, "*** %s : %s (%s:%d)\n", condition, message, file, line);
      fflush(stdout);
      failure = 1;
    }
    void equality_failure(const char* message, const char* x, const char* y, const char* file, int line) {
      fprintf(stdout, "*** %s == %s : %s (%s:%d)\n", x, y, message, file, line);
      fflush(stdout);
      failure = 1;
    }
    int run = 0, failed = 0;
    void run_code(void(*code)(void)) {
      failure = 0;
      code();
      if(failure) ++failed;
    }
    int main(int argc, char** argv) {
      setvbuf(stdout, NULL, _IONBF, 0);
      run_codes();
      if(failed) {
        printf("\n*** %d of %d unit(s) failed\n", failed, run);
      } else {
        printf("\n+++ all %d unit(s) succeeded\n", run);
      }
      exit(failed ? EXIT_FAILURE : EXIT_SUCCESS);
    }
  """
)
