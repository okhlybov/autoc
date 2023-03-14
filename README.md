# Reinvention of the C wheel, automatized

The project AutoC ships a collection of [Ruby](https://www.ruby-lang.org) classes related to automagic
C source code generation.

Specifically, it provides a means of generating strongly-typed general purpose C data containers
(vectors, lists, maps etc.) similar to those provided by
the C++'s [STL template containers](https://en.cppreference.com/w/cpp/container)
but implemented in ***pure ANSI C language***.

Unlike similar attempts to introduce type-generic data containers to the C language which
are typically the macro libraries, the AutoC is an ***explicit source code generator***
with 100% of provided functionality is implemented as (inline or extern) C functions
making the code explicit, browseable and debuggable.

## Qickstart

Install the `autoc` Ruby package from [RubyGems](https://rubygems.org)

```shell
gem install autoc
```

### Extract sample documentation

Generate a documentation header `auto.h` with reference of what can be provided by the AutoC

```shell
ruby -r autoc/scaffold -e docs
```

Extract the documentation with [Doxygen](https://www.doxygen.nl)

```shell
doxygen .
```

Explore the rendered HTML documentation starting at `html/index.html`

### Build & run sample project

Create auto code descriptor in Ruby `sample.rb`

```ruby
require 'autoc/module'
require 'autoc/hash_set'
AutoC::Module.render(:sample) do |m|
  m << AutoC::HashSet.new(:IntSet, :int)
end
```

Generate C code into `sample_auto.[ch]`

```shell
ruby sample.rb
```

Create sample C code `sample.c`

```c
#include <stdio.h>
#include "sample_auto.h"
int main(int argc, char** argv) {
  IntSet set;
  IntSetCreate(&set);
  IntSetPut(&set, 1);
  IntSetPut(&set, 0);
  IntSetPut(&set, 1);
  IntSetPut(&set, -1);
  printf("size = %d\\n", IntSetSize(&set));
  for(IntSetRange r = IntSetRangeNew(&set); !IntSetRangeEmpty(&r); IntSetRangePopFront(&r)) {
    printf("%d\\n", IntSetRangeTakeFront(&r));
  }
  IntSetDestroy(&set);
}
```

Build sample program

```shell
cc -g -o sample sample.c sample_auto.c
```

Test sample with [Valgrind](https://valgrind.org)

```shell
valgrind sample
```

### Build & run test suite

Generate C test suite into `tests_auto.[ch]`

```shell
ruby -r autoc/scaffold -e tests
```

Build test suite

```shell
cc -g -o tests tests_auto.c
```

Witness the test suite run time correctness

```shell
valgrind tests
```

### Create CMake project from template

Create CMake-powered skeleton project named `runme` in the current directory

```shell
ruby -r autoc/scaffold -e project runme
```

Configure the generated project

```shell
cmake .
```

Build the generated project

```shell
cmake --build .
```

## Licensing & availability

This code is distributed under terms of the 2-clause BSD {file:LICENSE}.

The project's home page is [GitHub](https://github.com/okhlybov/autoc).

The released ruby gems are published in [RubyGems](https://rubygems.org/gems/autoc).

The condensed description of the changes is in the {file:CHANGES.md}.


## Assorted related stuff

- [STC](https://github.com/tylov/STC)

---

_Cheers && happy coding!_

Oleg A. Khlybov <fougas@mail.ru>
