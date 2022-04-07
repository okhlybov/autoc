=begin

This is the AutoC automatic unit test generator.
Usage instruction:

1. Generate get test's source code (test_auto.c and test_auto.h):
> ruby -I . -I ../lib test.rb

2. Compile the generated code:
> cc test_auto.c
  
3. Run the tests:
> ./a.out

The code is intended to finish succesfully,
the process' exit code is zero when all tests are passed
ano non-zero if there were failed tests.

The compile-time warnings are possible and may be ignored.

The compiled code should also pass the memory leakage tests
(with Valgrind, Dr.Memory etc.)

=end

require 'autoc/module'

def type_test(cls, *opts, &code)
  t = Class.new(cls) do
    attr_reader :tests
    def initialize(*args)
      super
      @tests = []
      @test_names = []
    end
    def setup(code = nil)
      @setup_code = code
    end
    def cleanup(code = nil)
      @cleanup_code = code
    end
    def test(name, code)
      s = name.to_s
      @test_names << [name, func_name = eval("test#{s[0,1].upcase}#{s[1..-1]}")]
      @tests << %{
        static void #{func_name}(void) {
          #{@setup_code}
          #{code}
          #{@cleanup_code}
        }
      }
    end
    def definitions(stream)
      super
      @tests.each { |f| stream << f }
      stream << "static void #{run_tests}(void) {"
      stream << %{
        fprintf(stdout, "* %s\\n", "#{type}");
        fflush(stdout);
      }
      @test_names.each { |name, func_name| stream << %$run_test("#{name}", #{func_name});$ }
      stream << %$fputs("\\n", stdout); fflush(stdout);}$
    end
    def write_test_calls(stream)
      stream << "#{run_tests}();"
    end
  end.new(*opts)
  $tests << t
  t.instance_eval(&code)
end

class TestSuite

  include AutoC::Entity

  def forward_declarations(stream)
    super
    stream << %{
      #include <stdio.h>
      struct {
        int total, processed, failed;
      } tests;
      int failure;
      typedef void (*test_func)(void);
      static void run_test(const char* name, test_func func) {
        fprintf(stdout, "|   %s\\n", name);
        fflush(stdout);
        failure = 0;
        func();
        if(failure) tests.failed++;
        tests.processed++;
      }
      static void print_condition_failure(const char* message, const char* condition, const char* file, int line) {
        fprintf(stderr, "*** %s : %s (%s:%d)\\n", condition, message, file, line);
        fflush(stderr);
        failure = 1;
      }
      static void print_equality_failure(const char* message, const char* x, const char* y, const char* file, int line) {
        fprintf(stderr, "*** %s == %s : %s (%s:%d)\\n", x, y, message, file, line);
        fflush(stderr);
        failure = 1;
      }
      static void print_summary(void) {
        if(tests.failed)
          fprintf(stdout, "*** Failed %d of %d tests\\n", tests.failed, tests.processed);
        else
          fprintf(stdout, "+++ All %d tests passed successfully\\n", tests.processed);
        fflush(stdout);
      }
      #define TEST_MESSAGE(s) fprintf(stderr, "*** %s\\n", s); fflush(stderr);
      #define TEST_ASSERT(x) if(x) {} else print_condition_failure("evaluated to FALSE", #x, __FILE__, __LINE__)
      #define TEST_TRUE(x) if(x) {} else print_condition_failure("expected TRUE but got FALSE", #x, __FILE__, __LINE__)
      #define TEST_FALSE(x) if(x) print_condition_failure("expected FALSE but got TRUE", #x, __FILE__, __LINE__)
      #define TEST_NULL(x) if((x) == NULL) {} else print_condition_failure("expected NULL", #x, __FILE__, __LINE__)
      #define TEST_NOT_NULL(x) if((x) == NULL) print_condition_failure("expected not NULL", #x, __FILE__, __LINE__)
      #define TEST_EQUAL(x, y) if((x) == (y)) {} else print_equality_failure("expected equality", #x, #y, __FILE__, __LINE__)
      #define TEST_NOT_EQUAL(x, y) if((x) == (y)) print_equality_failure("expected non-equality", #x, #y, __FILE__, __LINE__)
      #define TEST_EQUAL_CHARS(x, y) if(strcmp(x, y) == 0) {} else print_equality_failure("expected strings equality", #x, #y, __FILE__, __LINE__)
      #define TEST_NOT_EQUAL_CHARS(x, y) if(strcmp(x, y) == 0) print_equality_failure("expected strings non-equality", #x, #y, __FILE__, __LINE__)
    }
  end

  def definitions(stream)
    super
    total = 0
    $tests.each { |t| total += t.tests.size }
    stream << "int main(int argc, char** argv) {"
    stream << %$
      tests.total = #{total};
      tests.processed = tests.failed = 0;
    $
    $tests.each { |t| t.write_test_calls(stream) }
    stream << "print_summary();"
    stream << "return tests.failed > 0;}"
  end
end

$tests = []

require_relative 'generic_value'
Value = GenericValue.new(:Value)

Dir['test_*.rb'].each { |t| load t }

AutoC::Module.render(:test) do |m|
  m << (s = TestSuite.new)
  $tests.each { |t| s.dependencies << t }
end