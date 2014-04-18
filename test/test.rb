require "autoc"

ValueType = {
  :type => :ValueType,
  :forward => %$#include "test.h"$,
  :ctor => :ValueTypeCtor,
  :dtor => :ValueTypeDtor,
  :copy => :ValueTypeCopy,
  :equal => :ValueTypeEqual,
  :less => :ValueTypeLess,
}

CodeBuilder::CModule.generate!(:Test) do |m|
  m << AutoC::Vector.new(:ValueTypeVector, ValueType)
end