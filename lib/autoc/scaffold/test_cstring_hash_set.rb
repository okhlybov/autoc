require 'autoc/hash_set'

require_relative 'test_cstring'

type_test(AutoC::HashSet, :CStringHashSet, CString) do

  ###

  setup %{
    #{self} t;
  }

  cleanup %{
    #{destroy}(&t);
  }

  test :create_default, %{
    #{default_create}(&t);
    TEST_EQUAL( #{size}(&t), 0 );
  }

  test :create_custom, %{
    #{create_capacity}(&t, 1024);
    TEST_EQUAL( #{size}(&t), 0 );
  }

  test :put, %{
    #{default_create}(&t);
    #{put}(&t, "kitty");
    #{put}(&t, "hello");
    #{put}(&t, "kitty");
    TEST_EQUAL( #{size}(&t), 2 );
  }

end