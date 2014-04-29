require "autoc"

ValueType = {
  :type => :ValueType,
  :forward => %$#include "test.h"$,
  :ctor => :ValueTypeCtor,
  :dtor => :ValueTypeDtor,
  :copy => :ValueTypeCopy,
  :equal => :ValueTypeEqual,
  :less => :ValueTypeLess,
  :identify => :ValueTypeIdentify,
}

AutoC::Module.generate!(:Test) do |c|
  c << AutoC::Vector.new(:ValueTypeVector, ValueType)
  c << AutoC::List.new(:ValueTypeList, ValueType)
  c << AutoC::Queue.new(:ValueTypeQueue, ValueType)
  c << AutoC::HashSet.new(:ValueTypeSet, ValueType)
  c << AutoC::HashMap.new(:ValueTypeMap, ValueType, ValueType)
end