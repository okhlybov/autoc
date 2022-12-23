require 'autoc/hash_set'

type_test(AutoC::HashSet, :IntHashSet, :int) do

	###

	setup %{
		#{self} t;
	}

	cleanup %{
		#{destroy}(&t);
	}

	test :create_empty, %{
		#{create}(&t);
		TEST_TRUE( #{empty}(&t) );
		TEST_EQUAL( #{size}(&t), 0 );
	}

	###

	setup %{
		#{self} t;
		#{create}(&t);
	}

	cleanup %{
		#{destroy}(&t);
	}

	test :put_uniques, %{
		TEST_TRUE( #{put}(&t, 0) );
		TEST_TRUE( #{put}(&t, -1) );
		TEST_TRUE( #{put}(&t, 1) );
		TEST_EQUAL( #{size}(&t), 3 );
	}

	test :put_duplicates, %{
		TEST_TRUE( #{put}(&t, 0) );
		TEST_TRUE( #{put}(&t, -1) );
		TEST_TRUE( #{put}(&t, 1) );
		TEST_FALSE( #{put}(&t, 0) );
		TEST_FALSE( #{put}(&t, 1) );
		TEST_FALSE( #{put}(&t, -1) );
		TEST_EQUAL( #{size}(&t), 3 );
	}

	test :push, %{
		TEST_FALSE( #{push}(&t, 1) );
		TEST_FALSE( #{push}(&t, -1) );
		TEST_TRUE( #{push}(&t, 1) );
		TEST_EQUAL( #{size}(&t), 2 );
	}

	test :contains, %{
		TEST_FALSE( #{contains}(&t, -1) );
		TEST_TRUE( #{put}(&t, -1) );
		TEST_TRUE( #{contains}(&t, -1) );
	}

	###

	setup %{
		#{self} t, r;
		#{create}(&t);
		#{create}(&r);
	}

	cleanup %{
		#{destroy}(&t);
		#{destroy}(&r);
	}

	test :remove_empty, %{
		TEST_EQUAL( #{size}(&t), 0 );
		TEST_FALSE( #{remove}(&t, 0) );
		TEST_TRUE( #{equal}(&t, &r) );
		TEST_TRUE( #{equal}(&r, &t) );
	}

	test :remove_nonexistent, %{
		TEST_TRUE( #{put}(&t, 1) );
		TEST_TRUE( #{put}(&t, 2) );
		TEST_TRUE( #{put}(&t, 3) );
		TEST_TRUE( #{put}(&r, 1) );
		TEST_TRUE( #{put}(&r, 2) );
		TEST_TRUE( #{put}(&r, 3) );
		TEST_EQUAL( #{size}(&t), 3 );
		TEST_FALSE( #{remove}(&t, 0) );
		TEST_TRUE( #{equal}(&t, &r) );
		TEST_TRUE( #{equal}(&r, &t) );
	}

	test :remove, %{
		TEST_TRUE( #{put}(&t, 1) );
		TEST_TRUE( #{put}(&t, 2) );
		TEST_TRUE( #{put}(&t, 3) );
		TEST_TRUE( #{put}(&r, 1) );
		TEST_TRUE( #{put}(&r, 3) );
		TEST_EQUAL( #{size}(&t), 3 );
		TEST_TRUE( #{contains}(&t, 2) );
		TEST_TRUE( #{remove}(&t, 2) );
		TEST_FALSE( #{contains}(&t, 2) );
		TEST_TRUE( #{equal}(&t, &r) );
		TEST_TRUE( #{equal}(&r, &t) );
	}

	###

	setup %{
		#{self} t1, t2;
		#{create}(&t1);
		#{create}(&t2);
	}

	cleanup %{
		#{destroy}(&t1);
		#{destroy}(&t2);
	}

	test :equal_empty, %{
		TEST_EQUAL( #{size}(&t1), 0 );
		TEST_EQUAL( #{size}(&t2), 0 );
		TEST_TRUE( #{equal}(&t1, &t2) );
	}

	test :equal_one, %{
		TEST_TRUE( #{put}(&t1, 3) );
		TEST_TRUE( #{put}(&t2, 3) );
		TEST_EQUAL( #{size}(&t1), 1 );
		TEST_EQUAL( #{size}(&t2), 1 );
		TEST_TRUE( #{equal}(&t1, &t2) );
	}

	test :equal, %{
		TEST_TRUE( #{put}(&t1, 3) );
		TEST_TRUE( #{put}(&t1, -3) );
		TEST_TRUE( #{put}(&t1, 0) );
		TEST_TRUE( #{put}(&t2, -3) );
		TEST_TRUE( #{put}(&t2, 0) );
		TEST_TRUE( #{put}(&t2, 3) );
		TEST_EQUAL( #{size}(&t1), 3 );
		TEST_EQUAL( #{size}(&t2), 3 );
		TEST_TRUE( #{equal}(&t1, &t2) );
	}

	test :subset_empty, %{
		TEST_TRUE( #{equal}(&t1, &t2) );
		TEST_TRUE( #{subset}(&t1, &t1) );
		TEST_TRUE( #{subset}(&t2, &t2) );
		TEST_TRUE( #{subset}(&t1, &t2) );
		TEST_TRUE( #{subset}(&t2, &t1) );
	}

	test :subset_equal, %{
		TEST_TRUE( #{put}(&t1, 1) );
		TEST_TRUE( #{put}(&t1, 2) );
		TEST_TRUE( #{put}(&t1, 3) );
		TEST_TRUE( #{put}(&t2, 3) );
		TEST_TRUE( #{put}(&t2, 2) );
		TEST_TRUE( #{put}(&t2, 1) );
		/* t2 == t1 */
		TEST_TRUE( #{equal}(&t1, &t2) );
		TEST_TRUE( #{subset}(&t1, &t1) );
		TEST_TRUE( #{subset}(&t2, &t2) );
		TEST_TRUE( #{subset}(&t1, &t2) );
		TEST_TRUE( #{subset}(&t2, &t1) );
	}

	test :subset, %{
		TEST_TRUE( #{put}(&t1, 1) );
		TEST_TRUE( #{put}(&t1, 2) );
		TEST_TRUE( #{put}(&t1, 3) );
		TEST_TRUE( #{put}(&t2, 2) );
		TEST_TRUE( #{put}(&t2, 1) );
		/* t2 < t1 */
		TEST_FALSE( #{equal}(&t1, &t2) );
		TEST_TRUE( #{subset}(&t1, &t1) );
		TEST_TRUE( #{subset}(&t2, &t2) );
		TEST_FALSE( #{subset}(&t1, &t2) );
		TEST_TRUE( #{subset}(&t2, &t1) );
	}

	test :disjoint, %{
		TEST_TRUE( #{put}(&t1, 1) );
		TEST_TRUE( #{put}(&t1, 2) );
		TEST_TRUE( #{put}(&t1, 3) );
		TEST_TRUE( #{put}(&t2, -1) );
		TEST_TRUE( #{put}(&t2, -2) );
		TEST_TRUE( #{put}(&t2, -3) );
		TEST_FALSE( #{equal}(&t1, &t2) );
		TEST_TRUE( #{disjoint}(&t1, &t2) );
		TEST_TRUE( #{disjoint}(&t2, &t1) );
		TEST_TRUE( #{put}(&t1, 0) );
		TEST_TRUE( #{put}(&t2, 0) );
		TEST_FALSE( #{disjoint}(&t1, &t2) );
		TEST_FALSE( #{disjoint}(&t2, &t1) );
	}

	test :disjoint_equal, %{
		TEST_TRUE( #{put}(&t1, 1) );
		TEST_TRUE( #{put}(&t1, 2) );
		TEST_TRUE( #{put}(&t1, 3) );
		TEST_TRUE( #{put}(&t2, 1) );
		TEST_TRUE( #{put}(&t2, 2) );
		TEST_TRUE( #{put}(&t2, 3) );
		TEST_TRUE( #{equal}(&t1, &t2) );
		TEST_FALSE( #{disjoint}(&t1, &t2) );
		TEST_FALSE( #{disjoint}(&t2, &t1) );
	}

	test :disjoint_empty, %{
		TEST_TRUE( #{equal}(&t1, &t2) );
		TEST_TRUE( #{disjoint}(&t1, &t2) );
		TEST_TRUE( #{disjoint}(&t2, &t1) );
	}

	###

	setup %{
		#{self} t1, t2, r;
		#{create}(&t1);
		#{create}(&t2);
		#{create}(&r);
	}

	cleanup %{
		#{destroy}(&t1);
		#{destroy}(&t2);
		#{destroy}(&r);
	}

	test :join_empty, %{
		#{join}(&t1, &t2);
		TEST_TRUE( #{equal}(&r, &t1) );
		TEST_TRUE( #{equal}(&r, &t2) );
	}

	test :join, %{
		TEST_TRUE( #{put}(&r, 1) );
		TEST_TRUE( #{put}(&r, 2) );
		TEST_TRUE( #{put}(&r, 3) );
		TEST_TRUE( #{put}(&t1, 1) );
		TEST_TRUE( #{put}(&t1, 2) );
		TEST_TRUE( #{put}(&t2, 1) );
		TEST_TRUE( #{put}(&t2, 3) );
		#{join}(&t1, &t2);
		TEST_TRUE( #{equal}(&r, &t1) );
		TEST_TRUE( #{equal}(&t1, &r) );
		TEST_FALSE( #{equal}(&r, &t2) );
		TEST_FALSE( #{equal}(&t2, &r) );
	}

	test :subtract, %{
		TEST_TRUE( #{put}(&r, 0) );
		TEST_TRUE( #{put}(&r, 2) );
		TEST_TRUE( #{put}(&t1, 0) );
		TEST_TRUE( #{put}(&t1, 1) );
		TEST_TRUE( #{put}(&t1, 2) );
		TEST_TRUE( #{put}(&t2, 1) );
		TEST_TRUE( #{put}(&t2, 3) );
		#{subtract}(&t1, &t2);
		TEST_TRUE( #{equal}(&r, &t1) );
		TEST_TRUE( #{equal}(&t1, &r) );
		TEST_FALSE( #{equal}(&r, &t2) );
		TEST_FALSE( #{equal}(&t2, &r) );
	}

	test :intersect_disjoint, %{
		TEST_TRUE( #{put}(&t1, 1) );
		TEST_TRUE( #{put}(&t1, 2) );
		TEST_TRUE( #{put}(&t1, 3) );
		TEST_TRUE( #{put}(&t2, -1) );
		TEST_TRUE( #{put}(&t2, -2) );
		TEST_TRUE( #{put}(&t2, -3) );
		#{intersect}(&t1, &t2);
		TEST_TRUE( #{equal}(&r, &t1) );
		TEST_TRUE( #{equal}(&t1, &r) );
	}

	test :intersect_equal, %{
		TEST_TRUE( #{put}(&t1, 1) );
		TEST_TRUE( #{put}(&t1, 2) );
		TEST_TRUE( #{put}(&t1, 3) );
		TEST_TRUE( #{put}(&t2, 1) );
		TEST_TRUE( #{put}(&t2, 2) );
		TEST_TRUE( #{put}(&t2, 3) );
		TEST_TRUE( #{put}(&r, 3) );
		TEST_TRUE( #{put}(&r, 2) );
		TEST_TRUE( #{put}(&r, 1) );
		#{intersect}(&t1, &t2);
		TEST_TRUE( #{equal}(&r, &t1) );
		TEST_TRUE( #{equal}(&t1, &r) );
		TEST_TRUE( #{equal}(&r, &t2) );
		TEST_TRUE( #{equal}(&t2, &r) );
		TEST_TRUE( #{equal}(&t1, &t2) );
		TEST_TRUE( #{equal}(&t2, &t1) );
	}

	test :intersect, %{
		TEST_TRUE( #{put}(&t1, 1) );
		TEST_TRUE( #{put}(&t1, 2) );
		TEST_TRUE( #{put}(&t1, 3) );
		TEST_TRUE( #{put}(&t2, -1) );
		TEST_TRUE( #{put}(&t2, -2) );
		TEST_TRUE( #{put}(&t2, -3) );
		TEST_TRUE( #{put}(&t1, 0) );
		TEST_TRUE( #{put}(&t2, 0) );
		TEST_TRUE( #{put}(&r, 0) );
		#{intersect}(&t1, &t2);
		TEST_TRUE( #{equal}(&r, &t1) );
		TEST_TRUE( #{equal}(&t1, &r) );
		TEST_FALSE( #{equal}(&r, &t2) );
		TEST_FALSE( #{equal}(&t2, &r) );
	}
end