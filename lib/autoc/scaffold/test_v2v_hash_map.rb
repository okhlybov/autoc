require 'autoc/hash_map'

type_test(AutoC::HashMap, :Value2HashMap, Value, Value) do

  ###

  setup %{
    #{self} t;
  }

  cleanup %{
    #{destroy}(&t);
  }

  test :create_empty, %{
    #{default_create.(:t)};
  }

  ###

  setup %{
    #{self} t;
    #{default_create.(:t)};
    TEST_TRUE( #{empty.(:t)} );
    TEST_EQUAL( #{size.(:t)}, 0 );
  }

  cleanup %{
    #{destroy}(&t);
  }

  test :put_single_identity, %{
    #{element} e;
    #{element.custom_create.(:e, -1)};
    #{set.(:t, :e, :e)};
    #{element.destroy.(:e)};
    TEST_FALSE( #{empty.(:t)} );
    TEST_EQUAL( #{size.(:t)}, 1 );
  }

  test :put_repeated_identity, %{
    #{element} e;
    #{element.custom_create.(:e, -1)};
    #{set.(:t, :e, :e)};
    #{set.(:t, :e, :e)};
    #{element.destroy.(:e)};
    TEST_FALSE( #{empty.(:t)} );
    TEST_EQUAL( #{size.(:t)}, 1 );
  }

  test :view_contains, %{
    #{element} e1, e2;
    #{element.custom_create.(:e1, -1)};
    #{element.custom_create.(:e2, +1)};
    #{set.(:t, :e1, :e2)};
    TEST_TRUE( #{contains.(:t, :e2)} );
    TEST_FALSE( #{contains.(:t, :e1)} );
    #{element.destroy.(:e1)};
    #{element.destroy.(:e2)};
    TEST_FALSE( #{empty.(:t)} );
    TEST_EQUAL( #{size.(:t)}, 1 );
  }

end