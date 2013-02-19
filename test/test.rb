require "autoc"


include CodeBuilder
include DataStructBuilder


Int = {:type=>"int"}
PChar = {:type=>"const char*", :compare=>"PCharCompare", :hash=>"PCharHash"}
Box = {:type=>"Box*", :forward=>"typedef struct Box Box;", :assign=>"BoxAssign", :compare=>"BoxCompare", :hash=>"BoxHash", :ctor=>"BoxNew", :dtor=>"BoxDestroy"}


CModule.generate!(:Test) do |m|
  m << Vector.new(:IntVector, Int)
  m << HashSet.new(:IntSet, Int)
  m << HashSet.new(:PCharSet, PChar)
  m << HashMap.new(:PChar2IntMap, PChar, Int)
  m << HashSet.new(:BoxSet, Box)
  m << Vector.new(:BoxVector, Box)
  m << List.new(:BoxList, Box)
end


