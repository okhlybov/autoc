require 'autoc/hash_map'

type_test(AutoC::HashMap, :Char2IntHashMap, :char, :int) do
  
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

  test :put, %$
    TEST_TRUE( #{put}(&t, 'a', 1) );
    TEST_FALSE( #{put}(&t, 'a', 1) );
		TEST_EQUAL( #{size}(&t), 1 );
  $

  test :force, %$
    TEST_FALSE( #{force}(&t, 'b', -1) );
    TEST_TRUE( #{force}(&t, 'b', -1) );
		TEST_EQUAL( #{size}(&t), 1 );
  $
end