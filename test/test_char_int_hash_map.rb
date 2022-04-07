require 'autoc/hash_map'

type_test(AutoC::HashMap, :Char2IntHashMap, :char, :int) do
  
	#

	setup %{ #{type} t; }
	cleanup %{ #{destroy}(&t); }

	test :create_empty, %{
		#{create}(&t);
		TEST_TRUE( #{empty}(&t) );
		TEST_EQUAL( #{size}(&t), 0 );
	}

	#

	setup %{
		#{type} t;
		#{create}(&t);
	}
	cleanup %{ #{destroy}(&t); }

  test :put, %{
		TEST_EQUAL( #{size}(&t), 0 );
		TEST_TRUE( #{put}(&t, 'a', 1) );
		TEST_EQUAL( #{size}(&t), 1 );
    TEST_FALSE( #{put}(&t, 'a', 1) );
		TEST_EQUAL( #{size}(&t), 1 );
  }

  test :set, %{
    TEST_FALSE( #{set}(&t, 'b', -1) );
    TEST_TRUE( #{set}(&t, 'b', -1) );
		TEST_EQUAL( #{size}(&t), 1 );
  }
end