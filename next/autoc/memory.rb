# frozen_string_literal: true


require 'singleton'
require 'autoc/type'
require 'autoc/module'


module AutoC


  # Standard C malloc()-based allocator.
  class Allocator

    include Singleton
    include Entity

    def allocate(type, count = 1, zero = false)
      zero ? "(#{type}*)calloc(#{count}, sizeof(#{type}))" : "(#{type}*)malloc((#{count})*sizeof(#{type}))"
    end

    def free(ptr) = "free(#{ptr})"

    def interface_declarations(stream)
      super
      stream << %$
        #include <stdlib.h>
      $
    end

    @@default = instance

    def self.default = @@default

    def self.default=(allocator) @@default = allocator end

  end # Allocator


  # Boehm garbage-collecting allocator.
  class Allocator::BDW

    include Singleton
    include Entity

    def allocate(type, count = 1, zero = false) = "(#{type}*)GC_malloc((#{count})*sizeof(#{type}))"

    def free(ptr) = nil

    def interface_declarations(stream)
      super
      stream << %$
        #include <gc.h>"
      $
    end

  end # BDW

end # AutoC