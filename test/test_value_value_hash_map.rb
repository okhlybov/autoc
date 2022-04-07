require 'autoc/hash_map'

type_test(AutoC::HashMap, :Value2ValueHashMap, Value, Value) do
  
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

  test :put_same, %{
    #{element.type} e;
    #{element.default_create}(&e);
		TEST_EQUAL( #{size}(&t), 0 );
		TEST_TRUE( #{put}(&t, e, e) );
		TEST_EQUAL( #{size}(&t), 1 );
    TEST_FALSE( #{put}(&t, e, e) );
		TEST_EQUAL( #{size}(&t), 1 );
    #{element.destroy}(&e);
  }

  xtest :put_clones, %{
    #{element.type} e1, e2;
    #{element.default_create}(&e1);
    #{element.default_create}(&e2);
		TEST_EQUAL( #{size}(&t), 0 );
		TEST_TRUE( #{put}(&t, e1, e2) );
		TEST_EQUAL( #{size}(&t), 1 );
    TEST_FALSE( #{put}(&t, e2, e1) );
		TEST_EQUAL( #{size}(&t), 1 );
    #{element.destroy}(&e1);
    #{element.destroy}(&e2);
  }
end