=begin rdoc

*AutoC* is a host of Ruby modules related to automatic C source code generation.

. Generic C multi-source module generator.
. Strongly-typed data structure generators akin the C++ STL container classes.

== Versioning scheme

=end
module AutoC
  VERSION = "0.9"
end # AutoC


require "autoc/code"
require "autoc/type"
require "autoc/collection"
require "autoc/collection/list"
require "autoc/collection/queue"
require "autoc/collection/vector"
require "autoc/collection/hash_set"
require "autoc/collection/hash_map"