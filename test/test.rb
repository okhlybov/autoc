require "autoc"


include CodeBuilder
include DataStructBuilder


Int = {:type=>"int", :compare=>nil}
PChar = {:type=>"const char*", :equal=>"PCharEqual", :hash=>"PCharHash"}
Box = {:type=>"Box*", :forward=>"typedef struct Box Box;", :assign=>"BoxAssign", :equal=>"BoxEqual", :hash=>"BoxHash", :ctor=>"BoxNew", :dtor=>"BoxDestroy"}


IntVector = Vector.new(:IntVector, Int)


CModule.generate!(:Test) do |m|
  m << IntVector
  m << Vector.new(:BoxVector, Box)
  m << List.new(:BoxList, Box)
  m << Queue.new(:PCharQueue, PChar)
  m << HashSet.new(:BoxSet, Box)
  m << HashSet.new(:IntSet, Int)
  m << HashSet.new(:PCharSet, PChar)
  m << HashMap.new(:Box2BoxMap, Box, Box)
  m << HashMap.new(:PChar2IntMap, PChar, Int)
  m << HashMap.new(:PChar2IntVectorMap, PChar, IntVector)
end