import autoc.core
import autoc.module
import autoc.core


codes = set()


autoc.core.decorator = autoc.core.snake_decorator


def _import_modules(package):
  import pkgutil
  import importlib
  for importer, module_name, is_pkg in pkgutil.walk_packages(package.__path__, package.__name__ + "."):
    importlib.import_module(module_name)


def configure_module(module):
  _import_modules(autoc.test)
  code = []
  code.append("void run_codes() {\n")
  for c in codes:
    module.add(c)
    code.append(f"run_code({c.name});\n")
  code.append("}")
  module.add(autoc.module.Code(definitions="".join(code)))


class Unit(autoc.module.Code):

  def __init__(self, name, dependencies=[]):
    super().__init__(dependencies=[code, *dependencies])
    self.name = name
    codes.add(self)

  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    if header:
      stream.append(f"void {self.name}();")

  def render_definitions(self, stream, header):
    super().render_definitions(stream, header)
    if not header:
      stream.append(f"void {self.name}() {{\n")
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
    #define TEST_MESSAGE(s) fprintf(stdout, "*** %s\\n", s); fflush(stdout);
    #define TEST_ASSERT(x) if(x) {} else condition_failure("evaluated to FALSE", #x, __FILE__, __LINE__)
    #define TEST_TRUE(x) if(x) {} else condition_failure("expected TRUE but got FALSE", #x, __FILE__, __LINE__)
    #define TEST_FALSE(x) if(x) condition_failure("expected FALSE but got TRUE", #x, __FILE__, __LINE__)
    #define TEST_NULL(x) if((x) == NULL) {} else condition_failure("expected NULL", #x, __FILE__, __LINE__)
    #define TEST_NOT_NULL(x) if((x) == NULL) condition_failure("expected not NULL", #x, __FILE__, __LINE__)
    #define TEST_EQUAL(x, y) if((x) == (y)) {} else equality_failure("expected equality", #x, #y, __FILE__, __LINE__)
    #define TEST_NOT_EQUAL(x, y) if((x) == (y)) equality_failure("expected non-equality", #x, #y, __FILE__, __LINE__)
    #define TEST_EQUAL_CHARS(x, y) if(strcmp(x, y) == 0) {} else equality_failure("expected strings equality", #x, #y, __FILE__, __LINE__)
    #define TEST_NOT_EQUAL_CHARS(x, y) if(strcmp(x, y) == 0) equality_failure("expected strings non-equality", #x, #y, __FILE__, __LINE__)
    void condition_failure(const char* message, const char* condition, const char* file, int line);
    void equality_failure(const char* message, const char* x, const char* y, const char* file, int line);
    void run_code(void(*code)());
    void run_codes();
  """,
  definitions=r"""
    #include <stdlib.h>
    #include <stdio.h>
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
    void run_code(void(*code)()) {
      failure = 0;
      code();
      if(failure) ++failed;
    }
    int main(int argc, char** argv) {
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