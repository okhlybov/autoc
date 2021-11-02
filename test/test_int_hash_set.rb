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
		TEST_TRUE( #{put}(&t, 0) );
		TEST_TRUE( #{put}(&t, -1) );
		TEST_TRUE( #{put}(&t, 1) );
		TEST_EQUAL( #{size}(&t), 3 );
	$

	test :put_duplicates, %$
		TEST_TRUE( #{put}(&t, 0) );
		TEST_TRUE( #{put}(&t, -1) );
		TEST_TRUE( #{put}(&t, 1) );
		TEST_FALSE( #{put}(&t, 1) );
		TEST_FALSE( #{put}(&t, 0) );
		TEST_FALSE( #{put}(&t, -1) );
		TEST_EQUAL( #{size}(&t), 3 );
	$

	test :force, %$
		TEST_FALSE( #{force}(&t, 1) );
		TEST_FALSE( #{force}(&t, -1) );
		TEST_TRUE( #{force}(&t, 1) );
		TEST_EQUAL( #{size}(&t), 2 );
	$

	setup %$
		#{type} t, r;
		#{create}(&t);
		#{create}(&r);
	$
	cleanup %$
		#{destroy}(&t);
		#{destroy}(&r);
	$

	test :remove_empty, %$
		TEST_EQUAL( #{size}(&t), 0 );
		TEST_FALSE( #{remove}(&t, 0) );
		TEST_TRUE( #{equal}(&t, &r) );
		TEST_TRUE( #{equal}(&r, &t) );
	$

	test :remove_nonexistent, %$
		#{put}(&t, 1);
		#{put}(&t, 2);
		#{put}(&t, 3);
		#{put}(&r, 1);
		#{put}(&r, 2);
		#{put}(&r, 3);
		TEST_EQUAL( #{size}(&t), 3 );
		TEST_FALSE( #{remove}(&t, 0) );
		TEST_TRUE( #{equal}(&t, &r) );
		TEST_TRUE( #{equal}(&r, &t) );
	$

	test :remove, %$
		#{put}(&t, 1);
		#{put}(&t, 2);
		#{put}(&t, 3);
		#{put}(&r, 1);
		#{put}(&r, 3);
		TEST_EQUAL( #{size}(&t), 3 );
		TEST_TRUE( #{remove}(&t, 2) );
		TEST_TRUE( #{equal}(&t, &r) );
		TEST_TRUE( #{equal}(&r, &t) );
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

	test :equal_empty, %$
		TEST_EQUAL( #{size}(&t1), 0 );
		TEST_EQUAL( #{size}(&t2), 0 );
		TEST_TRUE( #{equal}(&t1, &t2) );
	$

	test :equal_one, %$
		#{put}(&t1, 3);
		#{put}(&t2, 3);
		TEST_EQUAL( #{size}(&t1), 1 );
		TEST_EQUAL( #{size}(&t2), 1 );
		TEST_TRUE( #{equal}(&t1, &t2) );
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
		TEST_TRUE( #{equal}(&t1, &t2) );
	$

	test :subset_empty, %$
		TEST_TRUE( #{equal}(&t1, &t2) );
		TEST_TRUE( #{subset}(&t1, &t1) );
		TEST_TRUE( #{subset}(&t2, &t2) );
		TEST_TRUE( #{subset}(&t1, &t2) );
		TEST_TRUE( #{subset}(&t2, &t1) );
	$

	test :subset_equal, %$
		#{put}(&t1, 1);
		#{put}(&t1, 2);
		#{put}(&t1, 3);
		#{put}(&t2, 3);
		#{put}(&t2, 2);
		#{put}(&t2, 1);
		/* t2 == t1 */
		TEST_TRUE( #{equal}(&t1, &t2) );
		TEST_TRUE( #{subset}(&t1, &t1) );
		TEST_TRUE( #{subset}(&t2, &t2) );
		TEST_TRUE( #{subset}(&t1, &t2) );
		TEST_TRUE( #{subset}(&t2, &t1) );
	$

	test :subset, %$
		#{put}(&t1, 1);
		#{put}(&t1, 2);
		#{put}(&t1, 3);
		#{put}(&t2, 2);
		#{put}(&t2, 1);
		/* t2 < t1 */
		TEST_FALSE( #{equal}(&t1, &t2) );
		TEST_TRUE( #{subset}(&t1, &t1) );
		TEST_TRUE( #{subset}(&t2, &t2) );
		TEST_FALSE( #{subset}(&t1, &t2) );
		TEST_TRUE( #{subset}(&t2, &t1) );
	$

	test :disjoint, %$
		#{put}(&t1, 1);
		#{put}(&t1, 2);
		#{put}(&t1, 3);
		#{put}(&t2, -1);
		#{put}(&t2, -2);
		#{put}(&t2, -3);
		TEST_FALSE( #{equal}(&t1, &t2) );
		TEST_TRUE( #{disjoint}(&t1, &t2) );
		TEST_TRUE( #{disjoint}(&t2, &t1) );
		#{put}(&t1, 0);
		#{put}(&t2, 0);
		TEST_FALSE( #{disjoint}(&t1, &t2) );
		TEST_FALSE( #{disjoint}(&t2, &t1) );
	$

	test :disjoint_equal, %$
		#{put}(&t1, 1);
		#{put}(&t1, 2);
		#{put}(&t1, 3);
		#{put}(&t2, 1);
		#{put}(&t2, 2);
		#{put}(&t2, 3);
		TEST_TRUE( #{equal}(&t1, &t2) );
		TEST_FALSE( #{disjoint}(&t1, &t2) );
		TEST_FALSE( #{disjoint}(&t2, &t1) );
	$

	test :disjoint_empty, %$
		TEST_TRUE( #{equal}(&t1, &t2) );
		TEST_TRUE( #{disjoint}(&t1, &t2) );
		TEST_TRUE( #{disjoint}(&t2, &t1) );
	$

	setup %$
		#{type} t1, t2, r;
		#{create}(&t1);
		#{create}(&t2);
		#{create}(&r);
	$
	cleanup %$
		#{destroy}(&t1);
		#{destroy}(&t2);
		#{destroy}(&r);
	$

	test :join_empty, %$
		#{join}(&t1, &t2);
		TEST_TRUE( #{equal}(&r, &t1) );
		TEST_TRUE( #{equal}(&r, &t2) );
	$

	test :join, %$
		#{put}(&r, 1);
		#{put}(&r, 2);
		#{put}(&r, 3);
		#{put}(&t1, 1);
		#{put}(&t1, 2);
		#{put}(&t2, 1);
		#{put}(&t2, 3);
		#{join}(&t1, &t2);
		TEST_TRUE( #{equal}(&r, &t1) );
		TEST_TRUE( #{equal}(&t1, &r) );
		TEST_FALSE( #{equal}(&r, &t2) );
		TEST_FALSE( #{equal}(&t2, &r) );
	$

	test :subtract, %$
		#{put}(&r, 0);
		#{put}(&r, 2);
		#{put}(&t1, 0);
		#{put}(&t1, 1);
		#{put}(&t1, 2);
		#{put}(&t2, 1);
		#{put}(&t2, 3);
		#{subtract}(&t1, &t2);
		TEST_TRUE( #{equal}(&r, &t1) );
		TEST_TRUE( #{equal}(&t1, &r) );
		TEST_FALSE( #{equal}(&r, &t2) );
		TEST_FALSE( #{equal}(&t2, &r) );
	$

	test :intersect_disjoint, %$
		#{put}(&t1, 1);
		#{put}(&t1, 2);
		#{put}(&t1, 3);
		#{put}(&t2, -1);
		#{put}(&t2, -2);
		#{put}(&t2, -3);
		#{intersect}(&t1, &t2);
		TEST_TRUE( #{equal}(&r, &t1) );
		TEST_TRUE( #{equal}(&t1, &r) );
	$

	test :intersect_equal, %$
		#{put}(&t1, 1);
		#{put}(&t1, 2);
		#{put}(&t1, 3);
		#{put}(&t2, 1);
		#{put}(&t2, 2);
		#{put}(&t2, 3);
		#{put}(&r, 3);
		#{put}(&r, 2);
		#{put}(&r, 1);
		#{intersect}(&t1, &t2);
		TEST_TRUE( #{equal}(&r, &t1) );
		TEST_TRUE( #{equal}(&t1, &r) );
		TEST_TRUE( #{equal}(&r, &t2) );
		TEST_TRUE( #{equal}(&t2, &r) );
		TEST_TRUE( #{equal}(&t1, &t2) );
		TEST_TRUE( #{equal}(&t2, &t1) );
	$

	test :intersect, %$
		#{put}(&t1, 1);
		#{put}(&t1, 2);
		#{put}(&t1, 3);
		#{put}(&t2, -1);
		#{put}(&t2, -2);
		#{put}(&t2, -3);
		#{put}(&t1, 0);
		#{put}(&t2, 0);
		#{put}(&r, 0);
		#{intersect}(&t1, &t2);
		TEST_TRUE( #{equal}(&r, &t1) );
		TEST_TRUE( #{equal}(&t1, &r) );
		TEST_FALSE( #{equal}(&r, &t2) );
		TEST_FALSE( #{equal}(&t2, &r) );
	$
end