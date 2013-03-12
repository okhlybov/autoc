require "autoc"


include CodeBuilder
include DataStructBuilder


Int = {:type=>"int"}
PChar = {:type=>"const char*", :equal=>"PCharEqual", :hash=>"PCharHash"}
Box = {:type=>"Box*", :forward=>"typedef struct Box Box;", :assign=>"BoxAssign", :equal=>"BoxEqual", :hash=>"BoxHash", :ctor=>"BoxNew", :dtor=>"BoxDestroy"}


IntVector = Vector.new(:IntVector, Int)


CModule.generate!(:Test) do |m|
  m << HashSet.new(:IntSet, Int)
  m << HashSet.new(:PCharSet, PChar)
  m << HashMap.new(:PChar2IntMap, PChar, Int)
  m << HashSet.new(:BoxSet, Box)
  m << Vector.new(:BoxVector, Box)
  m << List.new(:BoxList, Box)
  m << HashMap.new(:Box2BoxMap, Box, Box)
  m << HashMap.new(:PChar2IntVectorMap, PChar, IntVector)
  m << IntVector
  m << Queue.new(:PCharQueue, PChar)
end


