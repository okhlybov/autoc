# Reinvention of the C wheel, automatized

This project presents is a collection of [Ruby](https://www.ruby-lang.org) modules related to automagic C source code generation.


## Qickstart

Install the `autoc` Ruby package from [RubyGems](https://rubygems.org)

```shell
gem install autoc
```


### Generate documentation

Generate reference documentation of the C interfaces in file `auto.h`

```shell
ruby -r autoc/scaffold -e docs
```

Extract documentation with [Doxygen](https://www.doxygen.nl)

```shell
doxygen .
```

Explore the rendered HTML documentation starting at `html/index.html`


### Run sample project

Create auto code descriptor in Ruby

`sample.rb`
```ruby
require 'autoc/hash_set'
AutoC::Module.render(:sample) do |m|
  m << AutoC::HashSet.new(:IntSet, :int)
end
```

Generate C code into `sample_auto.[ch]`

```shell
ruby sample.rb
```

Create C sample code

`sample.c`
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
  for(IntSetRange r = IntSetGetRange(&set); !IntSetRangeEmpty(&r); IntSetRangePopFront(&r)) {
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


### Run test suite

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


## Assorted related stuff

https://github.com/tylov/STC


## Licensing & availability

This code is distributed under the terms of 2-clause BSD license.

The project's home page is [GitHub](https://github.com/okhlybov/autoc).

The released ruby gems are published in [RubyGems](https://rubygems.org/gems/autoc).


---

_Cheers && happy coding!_

Oleg A. Khlybov <fougas@mail.ru>