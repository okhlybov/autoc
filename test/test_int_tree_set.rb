type_test(AutoC::TreeSet, :IntTreeSet, :int) do

setup %~#{type} t;~
cleanup %~#{dtor}(&t);~

	test :create, %~
		#{ctor}(&t);
		TEST_TRUE( #{empty}(&t) );
		TEST_EQUAL( #{size}(&t), 0 );
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
	int values[] = {1,2,5,6,7,4,3,1,0};
	int* p = &values;
	#{type} t;
	#{ctor}(&t);
	while(*p++) #{put}(&t, *p);
~
cleanup %~
	#{dtor}(&t);
~

	test :size, %~
		TEST_EQUAL( #{size}(&t), 7 );
	~

end