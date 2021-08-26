require 'autoc/hash_set'

type_test(AutoC::HashSet, :IntHashSet, :int) do

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

end