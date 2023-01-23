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
    #{element} e;
    #{default_create.(:t)};
    TEST_TRUE( #{empty.(:t)} );
    TEST_EQUAL( #{size.(:t)}, 0 );
    #{element.custom_create.(:e, -1)};
  }

  cleanup %{
    #{destroy.(:t)};
    #{element.destroy.(:e)};
  }

  test :put_single_identity, %{
    #{set.(:t, :e, :e)};
    TEST_FALSE( #{empty.(:t)} );
    TEST_EQUAL( #{size.(:t)}, 1 );
  }

  test :put_repeated_identity, %{
    #{set.(:t, :e, :e)};
    #{set.(:t, :e, :e)};
    TEST_FALSE( #{empty.(:t)} );
    TEST_EQUAL( #{size.(:t)}, 1 );
  }

  ###

  setup %{
    #{self} t;
    #{element} e1, e2;
    #{default_create.(:t)};
    TEST_TRUE( #{empty.(:t)} );
    TEST_EQUAL( #{size.(:t)}, 0 );
    #{element.custom_create.(:e1, -1)};
    #{element.custom_create.(:e2, +1)};
    #{set.(:t, :e1, :e2)};
    TEST_EQUAL( #{size.(:t)}, 1 );
  }
  
  cleanup %{
    #{destroy.(:t)};
    #{element.destroy.(:e1)};
    #{element.destroy.(:e2)};
  }

  test :view_contains, %{
    TEST_TRUE( #{contains.(:t, :e2)} );
    TEST_FALSE( #{contains.(:t, :e1)} );
    TEST_FALSE( #{empty.(:t)} );
    TEST_EQUAL( #{size.(:t)}, 1 );
  }

  test :remove, %{
    TEST_TRUE( #{contains.(:t, :e2)} );
    TEST_FALSE( #{contains.(:t, :e1)} );
    TEST_FALSE( #{remove.(:t, :e2)} );
    TEST_TRUE( #{remove.(:t, :e1)} );
    TEST_TRUE( #{empty.(:t)} );
  }

end