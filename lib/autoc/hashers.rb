require 'singleton'
require 'autoc/std'
require 'autoc/module'
require 'autoc/randoms'


module AutoC


  # Basic xor-shift incremental hasher
  class Hasher

    include Singleton

    include Entity

    def to_s = :size_t

    def create(hasher) = "#{hasher} = AUTOC_SEED"

    def destroy(hasher) = nil

    def update(hasher, value) = "#{hasher} = ((#{hasher} << 1) | (#{hasher} >> (sizeof(#{hasher})*CHAR_BIT - 1))) ^ (#{value})"

    def result(hasher) = hasher
    
    def initialize = dependencies << STD::LIMITS_H << STD::STDDEF_H << AutoC::Random.seed

  end # Hasher


end