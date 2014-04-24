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

AutoC::CModule.generate!(:Test) do |m|
  m << AutoC::Vector.new(:ValueTypeVector, ValueType)
  m << AutoC::List.new(:ValueTypeList, ValueType)
  m << AutoC::Queue.new(:ValueTypeQueue, ValueType)
  m << AutoC::HashSet.new(:ValueTypeHash, ValueType)
end