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

PInt = AutoC::Reference.new(:type => :int, :prefix => :Int)

PValueType = AutoC::Reference.new(ValueType)

IntVector = AutoC::Vector.new(:IntVector, :int)

IntSet = AutoC::HashSet.new(:IntSet, :int)

ListIntSet = AutoC::List.new(:ListIntSet, IntSet)

ValueTypeVector = Class.new(AutoC::Vector) do
  def write_intf(stream)
    super
    stream << %$#{extern} void #{test!}();$
  end
  def write_defs(stream)
    super
    stream << %$
      void #{test!}() {
        #{element.type} e1, e2;
        #{type} c1, c2;
        #{it} it;
        
        #{ctor}(&c1, 3);
        #{copy}(&c2, &c1);
        
        #{resize}(&c1, 5);
        #{size}(&c1);
        #{equal}(&c1, &c2);
        #{resize}(&c1, 3);
        #{size}(&c1);
        #{equal}(&c1, &c2);
        
        #{within}(&c1, 0);
        #{within}(&c1, 10);
        
        #{element.ctorEx}(&e1, -1);
        #{element.ctorEx}(&e2, +1);
        #{set}(&c1, 2, e1);
        #{set}(&c1, 0, e2);
        #{element.dtor}(e1);
        #{element.dtor}(e2);
        
        #{itCtor}(&it, &c1);
        while(#{itMove}(&it)) {
            #{element.type} e = #{itGet}(&it);
            #{element.dtor}(e);
        }
        
        #{itCtorEx}(&it, &c2, 0);
        while(#{itMove}(&it)) {
            #{element.type} e = #{itGet}(&it);
            #{element.dtor}(e);
        }
    
        #{sort}(&c1);
        #{sort}(&c2);
        
        #{identify}(&c1);
        #{identify}(&c2);
        
        #{dtor}(&c1);
        #{dtor}(&c2);
      }
    $
  end
end.new(:ValueTypeVector, ValueType)

ValueTypeList = Class.new(AutoC::List) do
  def write_intf(stream)
    super
    stream << %$#{extern} void #{test!}();$
  end
  def write_defs(stream)
    super
    stream << %$
      void #{test!}() {
        #{element.type} e1, e2, e3;
        #{type} c1, c2;
        #{it} it;
        
        #{ctor}(&c1);
        #{copy}(&c2, &c1);
        
        #{equal}(&c1, &c2);
        #{empty}(&c1);
        
        #{itCtor}(&it, &c1);
        while(#{itMove}(&it)) {
            #{element.type} e = #{itGet}(&it);
            #{element.dtor}(e);
        }
        
        #{element.ctorEx}(&e1, -1);
        #{element.ctorEx}(&e2, +1);
        
        #{push}(&c1, e1);
        #{push}(&c2, e2);
        #{contains}(&c1, e1);
        #{contains}(&c2, e1);
        #{push}(&c1, e2);
        #{push}(&c2, e1);
        #{empty}(&c1);
        
        #{element.dtor}(e1);
        #{element.dtor}(e2);
    
        e1 = #{peek}(&c1);
        e2 = #{peek}(&c2);
        #{element.dtor}(e1);
        #{element.dtor}(e2);
        
        #{itCtor}(&it, &c1);
        while(#{itMove}(&it)) {
            #{element.type} e = #{itGet}(&it);
            #{element.dtor}(e);
        }
    
        #{identify}(&c1);
        #{identify}(&c2);
    
        e1 = #{pop}(&c1);
        e2 = #{pop}(&c2);
        #{element.dtor}(e1);
        #{element.dtor}(e2);
    
        #{purge}(&c1);
        #{purge}(&c2);
    
        #{element.ctorEx}(&e1, 3);
        #{element.ctorEx}(&e2, -3);
        #{element.copy}(e3, e2);
        #{push}(&c1, e1);
        #{push}(&c1, e2);
        #{push}(&c1, e1);
        #{push}(&c2, e2);
        #{push}(&c2, e2);
        #{push}(&c2, e2);
        #{replace}(&c2, e3);
        #{replaceAll}(&c2, e3);
        #{remove}(&c1, e2);
        #{remove}(&c1, e1);
        #{remove}(&c2, e1);
        #{removeAll}(&c2, e2);
        #{element.dtor}(e1);
        #{element.dtor}(e2);
        #{element.dtor}(e3);
    
        #{dtor}(&c1);
        #{dtor}(&c2);
      }
    $
  end
end.new(:ValueTypeList, ValueType)

# Queue is a non-strict superset of List so the test case for the latter can be reused as-is
ValueTypeQueue = Class.new(AutoC::Queue) do
  def write_intf(stream)
    super
    stream << %$#{extern} void #{test!}();$
  end
  def write_defs(stream)
    super
    stream << %$
      void #{test!}() {
        #{element.type} e1, e2, e3;
        #{type} c1, c2;
        #{it} it;
        
        #{ctor}(&c1);
        #{copy}(&c2, &c1);
        
        #{equal}(&c1, &c2);
        #{empty}(&c1);
        
        #{itCtor}(&it, &c1);
        while(#{itMove}(&it)) {
            #{element.type} e = #{itGet}(&it);
            #{element.dtor}(e);
        }
        
        #{element.ctorEx}(&e1, -1);
        #{element.ctorEx}(&e2, +1);
        
        #{push}(&c1, e1);
        #{push}(&c2, e2);
        #{contains}(&c1, e1);
        #{contains}(&c2, e1);
        #{push}(&c1, e2);
        #{push}(&c2, e1);
        #{empty}(&c1);
        
        #{element.dtor}(e1);
        #{element.dtor}(e2);
    
        e1 = #{peek}(&c1);
        e2 = #{peek}(&c2);
        #{element.dtor}(e1);
        #{element.dtor}(e2);
        
        #{itCtor}(&it, &c1);
        while(#{itMove}(&it)) {
            #{element.type} e = #{itGet}(&it);
            #{element.dtor}(e);
        }
    
        #{identify}(&c1);
        #{identify}(&c2);
    
        e1 = #{pop}(&c1);
        e2 = #{pop}(&c2);
        #{element.dtor}(e1);
        #{element.dtor}(e2);
    
        #{purge}(&c1);
        #{purge}(&c2);
    
        #{element.ctorEx}(&e1, 3);
        #{element.ctorEx}(&e2, -3);
        #{element.copy}(e3, e2);
        #{push}(&c1, e1);
        #{push}(&c1, e2);
        #{push}(&c1, e1);
        #{push}(&c2, e2);
        #{push}(&c2, e2);
        #{push}(&c2, e2);
        #{replace}(&c2, e3);
        #{replaceAll}(&c2, e3);
        #{remove}(&c1, e2);
        #{remove}(&c1, e1);
        #{remove}(&c2, e1);
        #{removeAll}(&c2, e2);
        #{element.dtor}(e1);
        #{element.dtor}(e2);
        #{element.dtor}(e3);
    
        #{dtor}(&c1);
        #{dtor}(&c2);
      }
    $
  end
end.new(:ValueTypeQueue, ValueType)

ValueTypeSet = Class.new(AutoC::HashSet) do
  def write_intf(stream)
    super
    stream << %$#{extern} void #{test!}();$
  end
  def write_defs(stream)
    super
    stream << %$
      void #{test!}() {
        #{element.type} e1, e2, e3;
        #{type} c1, c2, cc1, cc2;
        #{it} it;
        
        #{ctor}(&c1);
        #{copy}(&c2, &c1);
        
        #{itCtor}(&it, &c1);
        while(#{itMove}(&it)) {
            #{element.type} e = #{itGet}(&it);
            #{element.dtor}(e);
        }
    
        #{equal}(&c1, &c2);
        #{empty}(&c1);
        #{size}(&c1);
        
        #{element.ctorEx}(&e1, -1);
        #{element.ctorEx}(&e2, +1);
        #{element.ctorEx}(&e3, 0);
    
        #{put}(&c1, e1);
        #{put}(&c2, e1);
        #{equal}(&c1, &c2);
        #{put}(&c1, e2);
        #{put}(&c2, e3);
        #{equal}(&c1, &c2);
        #{contains}(&c1, e1);
        #{contains}(&c2, e2);
        {
            #{element.type} e = #{get}(&c2, e3);
            #{element.dtor}(e);
        }
        #{replace}(&c1, e2);
    
        #{put}(&c2, e1);
        #{put}(&c2, e2);
        #{put}(&c2, e3);
        
        #{element.dtor}(e1);
        #{element.dtor}(e2);
        #{element.dtor}(e3);
        
        {
            int i;
            #{element.type} e;
            for(i = 0; i < 100; ++i) {
                #{element.ctorEx}(&e, i);
                #{put}(&c1, e);
                #{element.dtor}(e);
            }
            for(i = 0; i < 100; i += 2) {
                #{element.ctorEx}(&e, i);
                #{remove}(&c1, e);
                #{element.dtor}(e);
            }
            #{itCtor}(&it, &c1);
            while(#{itMove}(&it)) {
                #{element.type} e = #{itGet}(&it);
                #{element.dtor}(e);
            }
        }
        
        {
            #{copy}(&cc1, &c1);
            #{copy}(&cc2, &c2);
            #{retain}(&cc1, &cc2);
            #{dtor}(&cc1);
            #{dtor}(&cc2);
        }
        
        {
            #{copy}(&cc1, &c1);
            #{copy}(&cc2, &c2);
            #{retain}(&cc2, &cc1);
            #{dtor}(&cc1);
            #{dtor}(&cc2);
        }
    
        {
            #{copy}(&cc1, &c1);
            #{copy}(&cc2, &c2);
            #{include}(&cc1, &cc2);
            #{dtor}(&cc1);
            #{dtor}(&cc2);
        }
        
        {
            #{copy}(&cc1, &c1);
            #{copy}(&cc2, &c2);
            #{include}(&cc2, &cc1);
            #{dtor}(&cc1);
            #{dtor}(&cc2);
        }
    
        {
            #{copy}(&cc1, &c1);
            #{copy}(&cc2, &c2);
            #{exclude}(&cc1, &cc2);
            #{dtor}(&cc1);
            #{dtor}(&cc2);
        }
        
        {
            #{copy}(&cc1, &c1);
            #{copy}(&cc2, &c2);
            #{exclude}(&cc2, &cc1);
            #{dtor}(&cc1);
            #{dtor}(&cc2);
        }
    
        {
            #{copy}(&cc1, &c1);
            #{copy}(&cc2, &c2);
            #{invert}(&cc1, &cc2);
            #{dtor}(&cc1);
            #{dtor}(&cc2);
        }
        
        {
            #{copy}(&cc1, &c1);
            #{copy}(&cc2, &c2);
            #{invert}(&cc2, &cc1);
            #{dtor}(&cc1);
            #{dtor}(&cc2);
        }
    
        #{identify}(&c1);
        #{identify}(&c2);
    
        #{purge}(&c1);
        #{dtor}(&c1);
        #{dtor}(&c2);
      }
    $
  end
end.new(:ValueTypeSet, ValueType)

ValueTypeMap = Class.new(AutoC::HashMap) do
  def write_intf(stream)
    super
    stream << %$#{extern} void #{test!}();$
  end
  def write_defs(stream)
    super
    stream << %$
      void #{test!}() {
        #{element.type} e1, e2, e3;
        #{type} c1, c2;
        #{it} it;
        
        #{element.ctorEx}(&e1, -1);
        #{element.ctorEx}(&e2, +1);
        #{element.ctorEx}(&e3, 0);
    
        #{ctor}(&c1);
        #{put}(&c1, e1, e3);
        #{put}(&c1, e2, e3);
        #{copy}(&c2, &c1);
        
        #{put}(&c1, e1, e2);
        #{put}(&c2, e2, e1);
    
        {
            int i;
            #{element.type} e;
            for(i = 0; i < 100; ++i) {
                #{element.ctorEx}(&e, i);
                #{put}(&c1, e, e);
                #{element.dtor}(e);
            }
            for(i = 0; i < 100; i += 2) {
                #{element.ctorEx}(&e, i);
                #{remove}(&c1, e);
                #{element.dtor}(e);
            }
            for(i = 1; i < 10; ++i) {
                #{element.type} k;
                #{element.ctorEx}(&k, i);
                #{element.ctorEx}(&e, -i);
                #{replace}(&c1, k, e);
                #{element.dtor}(k);
                #{element.dtor}(e);
            }
        }
        
        #{itCtor}(&it, &c1);
        while(#{itMove}(&it)) {
            #{element.type} k = #{itGetKey}(&it), e = #{itGetElement}(&it);
            #{element.dtor}(k);
            #{element.dtor}(e);
        }
    
        #{element.dtor}(e1);
        #{element.dtor}(e2);
        #{element.dtor}(e3);
    
        #{equal}(&c1, &c2);
        #{empty}(&c1);
        #{size}(&c1);
        
        #{identify}(&c1);
        #{identify}(&c2);
    
        #{purge}(&c1);
        #{dtor}(&c1);
        #{dtor}(&c2);
      }
    $
  end
end.new(:ValueTypeMap, ValueType, ValueType)

CharString = Class.new(AutoC::String) do
  def write_intf(stream)
    super
    stream << %$#{extern} void #{test!}();$
  end
  def write_defs(stream)
    super
    stream << %$
      void #{test!}() {
        #{type} s1, s2, s3;
        #{ctor}(&s1, "z");
        #{ctor}(&s2, "x");
        #{pushInt}(&s1, 0);
        #{copy}(&s3, &s1);
        #{pushString}(&s3, &s2);
        #{pushPtr}(&s3, -1);
        printf("%s\\n", #{chars}(&s3));
        #{dtor}(&s3);
        #{dtor}(&s1);
        #{dtor}(&s2);
      }
    $
  end
end.new(:String)

AutoC::Module.generate!(:Test) do |c|
  c << ValueTypeVector
  c << ValueTypeList
  c << ValueTypeQueue
  c << ValueTypeSet
  c << ValueTypeMap
  c << AutoC::HashMap.new(:IntStrMap, :int, "const char *")
  c << ListIntSet
  c << IntSet
  c << AutoC::Vector.new(:PIntVector, PInt)
  c << PInt << PValueType
  c << AutoC::List.new(:ListPVectorValue, AutoC::Reference.new(AutoC::Vector.new(:PVectorValue, PValueType)))
  c << CharString
end