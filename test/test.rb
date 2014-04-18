require "autoc"

ValueType = {
  :type => :ValueType,
  :forward => %$#include "test2.h"$,
  :ctor => :ValueTypeCtor,
  :dtor => :ValueTypeDtor,
  :copy => :ValueTypeCopy,
  :equal => :ValueTypeEqual,
  :less => :ValueTypeLess,
}

CodeBuilder::CModule.generate!(:Test2) do |m|
  m << AutoC::Vector.new(:ValueTypeVector, ValueType)
end