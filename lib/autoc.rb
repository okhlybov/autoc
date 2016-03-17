=begin rdoc

*AutoC* is a host of Ruby modules related to automatic C source code generation.

. {AutoC::Code} generic C multi-source module generator.
. {AutoC::Collection} strongly-typed data structure generators similar
to the C++ STL container classes.
. {AutoC::String} wrapper around the standard C string with string building capability.

== Versioning scheme

AutoC adheres to simple major.minor versioning scheme.

Change in major number states incompatible changes in the code
while change in minor number states (rather) small incremental changes that
should not normally break things.

That said, release 1.0 is the _first_ release of version 1 which is considered beta, not stable.
_Note that it is not necessary stable or feature complete._
Releases 1.1+ will present incremental improvements, bugfixes, documentation updates etc. to version 1.
Should the major incompatible changes be made, the new release 2.0 will be introduced and so forth.

=end
module AutoC
  VERSION = "1.4"
end # AutoC


require "autoc/code"
require "autoc/type"
require "autoc/string"
require "autoc/collection"
require "autoc/collection/list"
require "autoc/collection/queue"
require "autoc/collection/vector"
require "autoc/collection/hash_set"
require "autoc/collection/hash_map"