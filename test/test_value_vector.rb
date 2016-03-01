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
    
setup %~
  #{type} t;
  #{element.type} e;
  int i, c = 3;
  #{ctor}(&t, c);
  for(i = 0; i < c; ++i) {
    #{element.ctorEx}(e, i);
    #{set}(&t, i, e);
    #{element.dtor}(e);
  }
~
cleanup %~#{dtor}(&t);~


  test :get, %~
    #{element.type} e2;
    #{element.ctorEx}(e, 2);
    e2 = #{get}(&t, 2);
    TEST_TRUE( #{element.equal}(e, e2) );
    #{element.dtor}(e);
    #{element.dtor}(e2);
  ~

  test :set, %~
    #{element.type} e2;
    #{element.ctorEx}(e, -1);
    #{set}(&t, 2, e);
    e2 = #{get}(&t, 2);
    TEST_TRUE( #{element.equal}(e, e2) );
    #{element.dtor}(e);
    #{element.dtor}(e2);
  ~

  test :within, %~
    TEST_TRUE( #{within}(&t, 0) );
    TEST_TRUE( #{within}(&t, 2) );
    TEST_FALSE( #{within}(&t, 3) );
  ~

  test :iterateForward, %~
    #{it} it;
    #{itCtor}(&it, &t);
    i = 0;
    while(#{itMove}(&it)) {
      e = #{itGet}(&it);
      TEST_EQUAL( #{element.get}(e), i++ );
      #{element.dtor}(e);
    }
  ~

  test :iterateBackward, %~
    #{it} it;
    #{itCtorEx}(&it, &t, 0);
    i = c-1;
    while(#{itMove}(&it)) {
      e = #{itGet}(&it);
      TEST_EQUAL( #{element.get}(e), i-- );
      #{element.dtor}(e);
    }
  ~

setup %~
  #{type} t1, t2;
  #{element.type} e;
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
  ~
cleanup %~
  #{dtor}(&t1);
  #{dtor}(&t2);
~

  test :size, %~
    TEST_EQUAL( #{size}(&t1), 3 );
    TEST_EQUAL( #{size}(&t1), #{size}(&t2) );
    #{resize}(&t2, 1);
    TEST_EQUAL( #{size}(&t2), 1 );
    TEST_NOT_EQUAL( #{size}(&t1), #{size}(&t2) );
  ~

  test :equal, %~
    #{element.ctorEx}(e, -1);
    #{set}(&t1, 0, e);
    #{element.dtor}(e);
    TEST_FALSE( #{equal}(&t1, &t2) );
  ~

  test :resizeShrink, %~
    #{resize}(&t2, 2);
    TEST_EQUAL( #{size}(&t2), 2 );
    TEST_FALSE( #{equal}(&t1, &t2) );
  ~

  test :resizeExpand, %~
    #{resize}(&t2, 4);
    TEST_EQUAL( #{size}(&t2), 4 );
    TEST_FALSE( #{equal}(&t1, &t2) );
    e = #{get}(&t2, 3);
    TEST_EQUAL( #{element.get}(e), 0 );
    TEST_NOT_EQUAL( #{element.get}(e), 1 );
    #{element.dtor}(e);
  ~

  test :sort, %~
    #{sort}(&t2);
    TEST_TRUE( #{equal}(&t1, &t2) );
    e = #{get}(&t2, 0);
    TEST_EQUAL( #{element.get}(e), 0 );
    #{element.dtor}(e);
    #{sortEx}(&t2, 0);
    TEST_FALSE( #{equal}(&t1, &t2) );
    e = #{get}(&t2, 0);
    TEST_EQUAL( #{element.get}(e), 2 );
    #{element.dtor}(e);
  ~

end