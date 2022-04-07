require 'autoc/hash_set'

type_test(AutoC::HashSet, :ValueHashSet, Value) do

  #

  setup %{ #{type} t; }
  cleanup %{ #{destroy}(&t); }

  test :create_default, %{
    #{default_create}(&t);
    TEST_EQUAL( #{size}(&t), 0 );
  }

  test :create_custom, %{
    #{create_capacity}(&t, 1024, 1);
    TEST_EQUAL( #{size}(&t), 0 );
  }

  #

  setup %{
    #{type} t;
    #{default_create}(&t);
  }
  cleanup %{ #{destroy}(&t); }

  test :put, %{
    #{element.type} e;
    #{element.create}(&e);
    TEST_TRUE( #{put}(&t, e) );
    TEST_EQUAL( #{size}(&t), 1 );
    TEST_FALSE( #{put}(&t, e) );
    TEST_EQUAL( #{size}(&t), 1 );
    #{element.destroy}(&e);
  }

  test :push, %{
    #{element.type} e1, e2;
    #{element.create}(&e1);
    #{element.set}(&e2, -1);
    TEST_FALSE( #{push}(&t, e1) );
    TEST_EQUAL( #{size}(&t), 1 );
    TEST_FALSE( #{push}(&t, e2) );
    TEST_EQUAL( #{size}(&t), 2 );
    TEST_TRUE( #{push}(&t, e1) );
    TEST_EQUAL( #{size}(&t), 2 );
    #{element.destroy}(&e1);
    #{element.destroy}(&e2);
  }
end