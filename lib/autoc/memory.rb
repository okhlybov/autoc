# frozen_string_literal: true


require 'singleton'
require 'autoc/std'
require 'autoc/type'
require 'autoc/module'


module AutoC


  # Standard C malloc()-based dynamic memory handler
  class Allocator

    include Singleton

    include Entity

    def initialize = dependencies << STD::STDLIB_H

    def allocate(type, count = 1, zero: false, **kws)
      zero ? "(#{type}*)calloc(#{count}, sizeof(#{type}))" : "(#{type}*)malloc((#{count})*sizeof(#{type}))"
    end

    def free(pointer) = "free(#{pointer})"

  end # Allocator


  # Boehm-Demers-Weiser garbage-collecting memory handler https://www.hboehm.info/gc/
  class BDWAllocator

    include Singleton

    include Entity

    def initialize = dependencies << SystemHeader.new('gc.h')

    def allocate(type, count = 1, atomic: false, **kws)
      atomic ? "(#{type}*)GC_malloc_atomic((#{count})*sizeof(#{type}))" : "(#{type}*)GC_malloc((#{count})*sizeof(#{type}))"
    end

    def free(pointer) = nil

  end # Allocator


end