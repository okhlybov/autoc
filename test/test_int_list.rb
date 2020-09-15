require 'autoc/list'

type_test(AutoC::List, :IntList, :int) do

	setup %$
		#{type} t;
	$
	cleanup %$
		#{destroy}(&t);
	$

	test :create, %$
		#{create}(&t);
		TEST_TRUE( #{empty}(&t) );
		TEST_EQUAL( #{size}(&t), 0 );
	$

	setup %$
		int i, c = 3;
		#{type} t1, t2;
		#{create}(&t1);
		#{create}(&t2);
		for(i = 0; i < c; ++i) {
			#{push}(&t1, i);
			#{push}(&t2, i);
		}
	$
	cleanup %$
		#{destroy}(&t1);
		#{destroy}(&t2);
	$

	test :equal, %$
		TEST_EQUAL( #{size}(&t1), #{size}(&t2) );
		TEST_TRUE( #{equal}(&t1, &t2) );
		#{push}(&t2, -1);
		TEST_NOT_EQUAL( #{size}(&t1), #{size}(&t2) );
		TEST_FALSE( #{equal}(&t1, &t2) );
	$

end