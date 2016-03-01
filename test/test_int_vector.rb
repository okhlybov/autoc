type_test(AutoC::Vector, :IntVector, :int) do

setup %~
  #{type} t1, t2;
  #{element.type} e;
  int i, c = 3;
  #{ctor}(&t1, c);
  #{ctor}(&t2, c);
  TEST_TRUE( #{equal}(&t1, &t2) );
  for(i = 0; i < c; ++i) {
    #{set}(&t1, i, i);
    #{set}(&t2, i, i);
  }
  TEST_TRUE( #{equal}(&t1, &t2) );
  ~
cleanup %~
  #{dtor}(&t1);
  #{dtor}(&t2);
~

test :sort, %~
	#{sortEx}(&t2, 0);
	/* 2,1,0 */
	TEST_FALSE( #{equal}(&t1, &t2) );
	TEST_EQUAL( #{get}(&t2, 0), 2 );
	TEST_EQUAL( #{get}(&t2, 1), 1 );
	#{sortEx}(&t2, 1);
	/* 0,1,2 */
	TEST_TRUE( #{equal}(&t1, &t2) );
	TEST_EQUAL( #{get}(&t2, 0), 0 );
	TEST_EQUAL( #{get}(&t2, 1), 1 );
~

end