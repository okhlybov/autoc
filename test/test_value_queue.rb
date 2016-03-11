require "value"

type_test(AutoC::Queue, :ValueQueue, Value) do
  
setup %~#{type} t;~
cleanup %~#{dtor}(&t);~

  test :create, %~
    #{ctor}(&t);
    TEST_EQUAL( #{size}(&t), 0 );
    TEST_TRUE( #{empty}(&t) );
  ~

setup %~
  /* [0,1,2] */
  #{type} t;
  #{element.type} e;
  int i, c = 3;
  #{ctor}(&t);
  for(i = 0; i < c; ++i) {
    #{element.ctorEx}(e, i);
    #{push}(&t, e);
    #{element.dtor(:e)};
  }
~
cleanup %~#{dtor}(&t);~

	test :copy, %~
		#{type} t2;
		#{copy}(&t2, &t);
		TEST_TRUE( #{equal}(&t2, &t) );
		{
			#{it} it;
			#{itCtor}(&it, &t);
			while(#{itMove}(&it)) {
        #{element.get}(e = #{itGet}(&it));
        #{element.dtor(:e)};
			}
		}
		#{dtor}(&t2);
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

  test :iterateExactForward, %~
    #{it} it;
    #{itCtorEx}(&it, &t, 1);
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
    i = #{size}(&t)-1;
    while(#{itMove}(&it)) {
      e = #{itGet}(&it);
      TEST_EQUAL( #{element.get}(e), i-- );
      #{element.dtor(:e)};
    }
  ~

  test :purge, %~
    TEST_FALSE( #{empty}(&t) );
    #{purge}(&t);
    TEST_TRUE( #{empty}(&t) );
  ~

  test :peek, %~
    size_t s1 = #{size}(&t);
    e = #{peek}(&t);
    TEST_EQUAL( #{element.get}(e), 0 );
    #{element.dtor(:e)};
    size_t s2 = #{size}(&t);
    TEST_EQUAL( s1, s2 );
  ~

  test :peekHead, %~
    size_t s1 = #{size}(&t);
    e = #{peekHead}(&t);
    TEST_EQUAL( #{element.get}(e), 0 );
    #{element.dtor(:e)};
    size_t s2 = #{size}(&t);
    TEST_EQUAL( s1, s2 );
  ~

  test :peekTail, %~
    size_t s1 = #{size}(&t);
    e = #{peekTail}(&t);
    TEST_EQUAL( #{element.get}(e), 2 );
    #{element.dtor(:e)};
    size_t s2 = #{size}(&t);
    TEST_EQUAL( s1, s2 );
  ~

  test :pop, %~
    size_t s1 = #{size}(&t);
    e = #{pop}(&t);
    TEST_EQUAL( #{element.get}(e), 0 );
    #{element.dtor(:e)};
    size_t s2 = #{size}(&t);
    TEST_EQUAL( s1-1, s2 );
  ~

  test :popHead, %~
    size_t s1 = #{size}(&t);
    e = #{popHead}(&t);
    TEST_EQUAL( #{element.get}(e), 0 );
    #{element.dtor(:e)};
    size_t s2 = #{size}(&t);
    TEST_EQUAL( s1-1, s2 );
  ~

  test :popTail, %~
    size_t s1 = #{size}(&t);
    e = #{popTail}(&t);
    TEST_EQUAL( #{element.get}(e), 2 );
    #{element.dtor(:e)};
    size_t s2 = #{size}(&t);
    TEST_EQUAL( s1-1, s2 );
  ~

  test :push, %~
    size_t s1 = #{size}(&t);
    #{element.ctorEx}(e, -1);
    #{push}(&t, e);
    #{element.dtor(:e)};
    size_t s2 = #{size}(&t);
    TEST_EQUAL( s1+1, s2 );
    e = #{peekTail}(&t);
    TEST_EQUAL( #{element.get}(e), -1 );
    #{element.dtor(:e)};
  ~

  test :pushTail, %~
    size_t s1 = #{size}(&t);
    #{element.ctorEx}(e, -1);
    #{pushTail}(&t, e);
    #{element.dtor(:e)};
    size_t s2 = #{size}(&t);
    TEST_EQUAL( s1+1, s2 );
    e = #{peekTail}(&t);
    TEST_EQUAL( #{element.get}(e), -1 );
    #{element.dtor(:e)};
  ~

  test :pushHead, %~
    size_t s1 = #{size}(&t);
    #{element.ctorEx}(e, -1);
    #{pushHead}(&t, e);
    #{element.dtor(:e)};
    size_t s2 = #{size}(&t);
    TEST_EQUAL( s1+1, s2 );
    e = #{peekHead}(&t);
    TEST_EQUAL( #{element.get}(e), -1 );
    #{element.dtor(:e)};
  ~

  test :contains, %~
    #{element.ctorEx}(e, -1);
    TEST_FALSE( #{contains}(&t, e) );
    #{element.set}(e, 1);
    TEST_TRUE( #{contains}(&t, e) );
    #{element.dtor(:e)};
  ~

  test :find, %~
    #{element.type} e2;
    #{element.ctorEx}(e, 1);
    e2 = #{find}(&t, e);
    TEST_TRUE( #{element.equal}(e, e2) );
    #{element.dtor(:e)};
    #{element.dtor(:e2)};
  ~

setup %~
  /* [0,1,2,0] */
  #{type} t1, t2;
  #{element.type} e;
  int i, c = 3;
  #{ctor}(&t1);
  #{ctor}(&t2);
  TEST_TRUE( #{equal}(&t1, &t2) );
  for(i = 0; i < c; ++i) {
    #{element.ctorEx}(e, i);
    #{push}(&t1, e);
    #{push}(&t2, e);
    #{element.dtor(:e)};
  }
  #{element.ctorEx}(e, 0);
  #{push}(&t1, e);
  #{push}(&t2, e);
  #{element.dtor(:e)};
  TEST_TRUE( #{equal}(&t1, &t2) );
  ~
cleanup %~
  #{dtor}(&t1);
  #{dtor}(&t2);
~

  test :equal, %~
    TEST_TRUE( #{equal}(&t1, &t2) );
    #{element.ctorEx}(e, -1);
    #{push}(&t2, e);
    #{element.dtor(:e)};
    TEST_FALSE( #{equal}(&t1, &t2) );
  ~

  test :replaceNone, %~
    #{element.ctorEx}(e, -1);
    TEST_FALSE( #{replace}(&t2, e) );
    TEST_TRUE( #{equal}(&t1, &t2) );
    #{element.dtor(:e)};
  ~

  test :replaceOne, %~
    #{element.ctorEx}(e, 0);
    TEST_EQUAL( #{replace}(&t2, e), 1 );
    #{element.dtor(:e)};
  ~

  test :replaceExactOne, %~
    #{element.ctorEx}(e, 0);
    TEST_EQUAL( #{replaceEx}(&t2, e, 1), 1 );
    #{element.dtor(:e)};
  ~

  test :replaceAll, %~
    #{element.ctorEx}(e, 0);
    TEST_EQUAL( #{replaceAll}(&t2, e), 2 );
    #{element.dtor(:e)};
  ~

  test :removeNone, %~
    #{element.ctorEx}(e, -1);
    TEST_FALSE( #{remove}(&t2, e) );
    TEST_TRUE( #{equal}(&t1, &t2) );
    #{element.dtor(:e)};
  ~

  test :removeOne, %~
    #{element.ctorEx}(e, 0);
    TEST_EQUAL( #{remove}(&t2, e), 1 );
    TEST_EQUAL( #{size}(&t1)-1, #{size}(&t2) );
    #{element.dtor(:e)};
  ~

  test :removeExactOne, %~
    #{element.ctorEx}(e, 0);
    TEST_EQUAL( #{removeEx}(&t2, e, 1), 1 );
    TEST_EQUAL( #{size}(&t1)-1, #{size}(&t2) );
    #{element.dtor(:e)};
  ~

  test :removeAll, %~
    #{element.ctorEx}(e, 0);
    TEST_EQUAL( #{removeAll}(&t2, e), 2 );
    TEST_EQUAL( #{size}(&t1)-2, #{size}(&t2) );
    #{element.dtor(:e)};
  ~

end