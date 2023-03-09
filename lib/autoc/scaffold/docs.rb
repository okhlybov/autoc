require 'autoc'
require 'autoc/module'

main = AutoC::Code.new interface: %{
  /**
    @mainpage AutoC-generated interface reference version #{AutoC::VERSION}

    @section intro Introduction

    The AutoC provides a set of source code generators for widely-known containers such as vector, list, set, map etc.
    The result is similar to that of the C++ STL template classes which generate the specialized versions of
    the generic containers but in this case in ***pure C language***.

    @section start Kick start

    Suppose one needs to have a pure C implementation of the set of integer values (`std::unordered_set<int>` in C++ terms).
    Such code may be obtained with AutoC by executing the following instructions.

    1. Install the AutoC gem
    ```shell
    > gem install autoc
    ```
    2. Create the type implementation generator in file `test.rb`
    ```ruby
    require 'autoc/hash_set'
    AutoC::Module.render(:test) do |m|
      m << AutoC::HashSet.new(:IntSet, :int)
    end
    ```
    3. Generate the type implementation
    ```shell
    > ruby test.rb
    ```
    4. Extract the code-specific auto-generated interface documentation
    ```shell
    > doxygen .
    ```
    5. Create a test code in file `test.c`
    ```c
    #include <stdio.h>
    #include "test_auto.h"
    int main(int argc, char** argv) {
      IntSet set;
      IntSetCreate(&set);
      IntSetPut(&set, 1);
      IntSetPut(&set, 0);
      IntSetPut(&set, 1);
      printf("size = %d\\n", IntSetSize(&set));
      for(IntSetRange r = IntSetRangeNew(&set); !IntSetRangeEmpty(&r); IntSetRangePopFront(&r)) {
        printf("%d\\n", IntSetRangeTakeFront(&r));
      }
      IntSetDestroy(&set);
    }
    ```
    6. Compile the test executable
    ```shell
    > cc -g -o test test.c test_auto.c
    ```
    7. Perform a test run with Valgrind
    ```shell
    > valgrind ./test
    ```
  */
  }

require_relative 'generic_value'

# @private
class DocsValue < GenericValue
  attr_reader :description
  def initialize(type, desc)
    super(type)
    @description = desc
  end
end

A = DocsValue.new(:A, 'Generic value type')
B = DocsValue.new(:B, 'Generic value type')
T = DocsValue.new(:T, 'Generic value type')
K = DocsValue.new(:K, 'Generic hashable value type')

# @private
class Docs < AutoC::Module
  def initialize(*args, **kws)
    super
    class << header
      def file_name = 'autoc.h'
    end
  end
  def render
    distribute_entities
    header.render
  end
end

require 'autoc/cstring'

require 'autoc/list'
require 'autoc/vector'
require 'autoc/hash_set'
require 'autoc/hash_map'

require 'autoc/box'
require 'autoc/record'

m = Docs.new(:autoc)

m << main
m << AutoC::CString.new
m << AutoC::Vector.new(:Vector, T)
m << AutoC::List.new(:List, T)
m << AutoC::HashSet.new(:HashSet, T)
m << AutoC::HashMap.new(:HashMap, T, K)
m << AutoC::Box.new(:Box, { a: A, b: B })
m << AutoC::Record.new(:Record, { a: A, b: B })

m.render