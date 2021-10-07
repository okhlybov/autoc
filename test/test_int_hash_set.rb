require 'autoc/hash_set'

type_test(AutoC::HashSet, :IntHashSet, :int) do

	setup %$
		#{type} t;
	$
	cleanup %$
		#{destroy}(&t);
	$

	test :create_empty, %$
		#{create}(&t);
		TEST_TRUE( #{empty}(&t) );
		TEST_EQUAL( #{size}(&t), 0 );
	$

	setup %$
		#{type} t;
		#{create}(&t);
	$
	cleanup %$
		#{destroy}(&t);
	$

	test :put_uniques, %$
		#{put}(&t, 0);
		#{put}(&t, -1);
		#{put}(&t, 1);
		TEST_EQUAL( #{size}(&t), 3 );
	$

	test :put_duplicates, %$
		#{put}(&t, 0);
		#{put}(&t, -1);
		#{put}(&t, 1);
		#{put}(&t, 1);
		#{put}(&t, 0);
		#{put}(&t, -1);
		TEST_EQUAL( #{size}(&t), 3 );
	$

	setup %$
		#{type} t1, t2;
		#{create}(&t1);
		#{create}(&t2);
	$
	cleanup %$
		#{destroy}(&t1);
		#{destroy}(&t2);
	$

	test :equal_0, %$
		TEST_EQUAL( #{size}(&t1), 0 );
		TEST_EQUAL( #{size}(&t2), 0 );
		TEST_EQUAL( #{equal}(&t1, &t2), 1 );
	$

	test :equal_1, %$
		#{put}(&t1, 3);
		#{put}(&t2, 3);
		TEST_EQUAL( #{size}(&t1), 1 );
		TEST_EQUAL( #{size}(&t2), 1 );
		TEST_EQUAL( #{equal}(&t1, &t2), 1 );
	$

	test :equal, %$
		#{put}(&t1, 3);
		#{put}(&t1, -3);
		#{put}(&t1, 0);
		#{put}(&t2, -3);
		#{put}(&t2, 0);
		#{put}(&t2, 3);
		TEST_EQUAL( #{size}(&t1), 3 );
		TEST_EQUAL( #{size}(&t2), 3 );
		TEST_EQUAL( #{equal}(&t1, &t2), 1 );
	$
end