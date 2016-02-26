require "autoc"


Prologue = Class.new(AutoC::Code) do
  def write_defs(stream)
    stream << %~
      #include <stdio.h>
      #define TEST_TRUE(x) 
      char* current_test_name;
      struct {
        int total, processed, failed;
      } tests;
      void print_summary(FILE* file) {
        fprintf(file, "*** Processed %d of %d tests\\n", tests.processed, tests.total);
      }
    ~
  end
end.new


Epilogue = Class.new(AutoC::Code) do
  def priority; AutoC::Priority::MIN end
  def write_defs(stream)
    total = 0
    $tests.each {|t| total += t.tests.size}
    stream << %~int main(int argc, char** argv) {~
    stream << %~
      tests.total = #{total};
      tests.processed = tests.failed = 0;
    ~
    $tests.each {|t| t.write_test_calls(stream)}
    stream << %~print_summary(stdout);~
    stream << %~return tests.failed > 0;}~
  end
end.new


$tests = []


def type_test(cls, *opts, &code)
  t = Class.new(cls) do
    def entities; super << Prologue end
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
      @test_names << [name, func_name = eval("#{name}Test")]
      @tests << %~
        void #{func_name}(void) {
          #{@setup_code}
          #{code}
          #{@cleanup_code}
        }
      ~
    end
    def write_defs(stream)
      super
      @tests.each {|f| stream << f}
      stream << %~void #{runTests}(void) {~
        @test_names.each do |name, func_name|
          stream << %$
            current_test_name = "#{type}\##{name}";
            #{func_name}();
            tests.processed++;
          $
        end
      stream << %~}~
    end
    def write_test_calls(stream)
      stream << %$
        #{runTests}();
      $
    end
  end.new(*opts)
  $tests << t
  t.instance_eval(&code)
end


Dir["**/test_*.rb"].each {|t| load t}
  
  
AutoC::Module.generate!(:Test) do |c|
  c << Prologue
  $tests.each {|t| c << t}
  c << Epilogue
end