require 'autoc'


include CodeBuilder
include DataStructBuilder


Int = {:type=>'int'}
PChar = {:type=>'const char*', :compare=>'PCharCompare', :hash=>'PCharHash'}


CModule.generate!(:test) do |m|
  m << Vector.new(:IntVector, Int)
  m << HashSet.new(:IntSet, Int)
  m << HashSet.new(:PCharSet, PChar)
  m << HashMap.new(:PChar2IntMap, PChar, Int)
end


