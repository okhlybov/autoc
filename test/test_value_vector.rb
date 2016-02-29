require "value"


type_test(AutoC::Vector, :ValueVector, Value) do
  
setup %~#{type} t;~
cleanup %~#{dtor}(&t);~

  test :createSmallest, %~
    #{ctor}(&t, 1);
    TEST_EQUAL( #{size}(&t), 1 );
  ~
    
  test :createLarge, %~
    #{ctor}(&t, 1024);
    TEST_EQUAL( #{size}(&t), 1024 );
  ~
    
setup %~#{type} t1, t2; #{element.type} e;~
cleanup %~#{dtor}(&t1); #{dtor}(&t2);~

  test :equal, %~
    int i, c = 3;
    #{ctor}(&t1, c);
    #{ctor}(&t2, c);
    TEST_TRUE( #{equal}(&t1, &t2) );
    for(i = 0; i < c; ++i) {
      #{element.ctorEx}(e, i);
      #{set}(&t1, i, e);
      #{set}(&t2, i, e);
      #{element.dtor}(e);
    }
    TEST_TRUE( #{equal}(&t1, &t2) );
    #{element.ctorEx}(e, -1);
    #{set}(&t1, 0, e);
    #{element.dtor}(e);
    TEST_FALSE( #{equal}(&t1, &t2) );
  ~
  
end