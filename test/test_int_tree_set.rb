type_test(AutoC::TreeSet, :IntTreeSet, :int) do

setup %~#{type} t; #{ctor}(&t);~
cleanup %~#{dtor}(&t);~

	test :create, %~
		TEST_TRUE( #{empty}(&t) );
		TEST_EQUAL( #{size}(&t), 0 );
	~

	test :put, %~
		TEST_EQUAL( #{size}(&t), 0 );
		TEST_FALSE( #{contains}(&t, 1) );
		TEST_TRUE( #{put}(&t, 1) );
		TEST_TRUE( #{contains}(&t, 1) );
		TEST_FALSE( #{put}(&t, 1) );
		TEST_EQUAL( #{size}(&t), 1 );
		TEST_TRUE( #{put}(&t, -1) );
		TEST_TRUE( #{put}(&t, 2) );
		TEST_EQUAL( #{size}(&t), 3 );
		TEST_FALSE( #{contains}(&t, 0) );
	~

setup %~
	int i, c = 3;
	#{type} t1, t2;
	#{ctor}(&t1);
	#{ctor}(&t2);
	for(i = 0; i < c; ++i) {
		#{put}(&t1, i);
		#{put}(&t2, i);
	}
~
cleanup %~
	#{dtor}(&t1);
	#{dtor}(&t2);
~

	test :equal, %~
		TEST_EQUAL( #{size}(&t1), #{size}(&t2) );
		TEST_TRUE( #{equal}(&t1, &t2) );
		#{put}(&t2, -1);
		TEST_NOT_EQUAL( #{size}(&t1), #{size}(&t2) );
		TEST_FALSE( #{equal}(&t1, &t2) );
	~

setup %~
	int values[] = {2,-6,7,-6,1,2,5,7,4,3,1,-6,0};
	int* p = values;
	#{type} t;
	#{ctor}(&t);
	while(*p != 0) {
		#{put}(&t, *p);
		TEST_TRUE( #{contains}(&t, *p) );
		++p;
	}
~
cleanup %~
	#{dtor}(&t);
~

	test :size, %~
		TEST_EQUAL( #{size}(&t), 7 );
	~

	test :contains, %~
		TEST_TRUE( #{contains}(&t, 1) );
		TEST_FALSE( #{contains}(&t, -1) );
	~

	test :iterateAscending, %~
		int cur = 0, pre = 0, start = 1;
		#{it} it;
		#{itCtorEx}(&it, &t, 1);
		while(#{itMove}(&it)) {
			cur = #{itGet}(&it);
			if(start) {
				start = 0;
			} else {
				TEST_TRUE( pre < cur );
				pre = cur;
			}
		}
	~

	test :iterateDescending, %~
		int cur = 0, pre = 0, start = 1;
		#{it} it;
		#{itCtorEx}(&it, &t, 0);
		while(#{itMove}(&it)) {
			cur = #{itGet}(&it);
			if(start) {
				start = 0;
			} else {
				TEST_TRUE( pre > cur );
				pre = cur;
			}
		}
	~

	test :peekHighest, %~
		TEST_EQUAL( #{peekHighest}(&t), 7 );
	~

	test :peekLowest, %~
		TEST_EQUAL( #{peekLowest}(&t), -6 );
	~

end