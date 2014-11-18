require "autoc"

ValueType = {
  :type => :ValueType,
  :ctor => :ValueTypeCtor,
  :dtor => :ValueTypeDtor,
  :copy => :ValueTypeCopy,
  :equal => :ValueTypeEqual,
  :less => :ValueTypeLess,
  :identify => :ValueTypeIdentify,
  :forward => %$#include "test.h"$,
}

PInt = AutoC::Reference.new(:type => "int", :prefix => "Int")

PValueType = AutoC::Reference.new(ValueType)

IntVector = AutoC::Vector.new(:IntVector, :int)

IntSet = AutoC::HashSet.new(:IntSet, :int)

ListIntSet = AutoC::List.new(:ListIntSet, IntSet)

AutoC::Module.generate!(:Test) do |c|
  c << AutoC::Vector.new(:ValueTypeVector, ValueType)
  c << AutoC::List.new(:ValueTypeList, ValueType)
  c << AutoC::Queue.new(:ValueTypeQueue, ValueType)
  c << AutoC::HashSet.new(:ValueTypeSet, ValueType)
  c << AutoC::HashMap.new(:ValueTypeMap, ValueType, ValueType)
  c << AutoC::HashMap.new(:IntStrMap, "int", "const char *")
  c << ListIntSet
  c << IntSet
  c << AutoC::Vector.new(:PIntVector, PInt)
  c << PInt << PValueType
  c << AutoC::List.new(:ListPVectorValue, AutoC::Reference.new(AutoC::Vector.new(:PVectorValue, PValueType)))
end