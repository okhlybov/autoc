require 'autoc/vector'

IntVector = type_test(AutoC::Vector, :IntVector, :int) do

  ###

  setup %{
    #{self} t;
  }

  cleanup %{
    #{destroy}(&t);
  }

  test :create, %{
    #{default_create.(:t)};
    TEST_EQUAL( #{size}(&t), 0 );
  }

  test :create_size, %{
    #{custom_create.(:t, 100)};
    TEST_EQUAL( #{size}(&t), 100 );
  }

  ###

  setup %{
    #{self} t1, t2;
    int i, c = 3;
    #{custom_create.(:t1, :c)};
    #{custom_create.(:t2, :c)};
    for(i = 0; i < c; ++i) {
      #{set}(&t1, i, i);
      #{set}(&t2, i, i);
      /* 0,1,2 */
    }
  }

  cleanup %{
    #{destroy}(&t1);
    #{destroy}(&t2);
  }

  test :equal_identity, %{
    TEST_TRUE( #{equal.(:t1, :t1)} );
    TEST_TRUE( #{equal.(:t2, :t2)} );
  }

  test :equal, %{
    TEST_TRUE( #{equal.(:t1, :t2)} );
  }

  test :not_equal, %{
    #{set}(&t1, 1, -1);
    TEST_FALSE( #{equal.(:t1, :t2)} );
  }

  test :sort_resort, %{
    #{sort}(&t2, -1);
    TEST_EQUAL( #{get}(&t2, 0), 2);
    TEST_FALSE( #{equal.(:t1, :t2)} );
    #{sort}(&t2, +1);
    TEST_EQUAL( #{get}(&t2, 0), 0);
    TEST_TRUE( #{equal.(:t1, :t2)} );
  }

  test :sort_descend, %{
    #{sort}(&t2, -1);
    /* 2,1,0 */
    TEST_FALSE( #{equal.(:t1, :t2)} );
    TEST_EQUAL( #{get}(&t2, 0), 2 );
    TEST_EQUAL( #{get}(&t2, 1), 1 );
  }

  test :sort_ascend, %{
    #{sort}(&t2, +1);
    /* 0,1,2 */
    TEST_TRUE( #{equal.(:t1, :t2)} );
    TEST_EQUAL( #{get}(&t2, 0), 0 );
    TEST_EQUAL( #{get}(&t2, 1), 1 );
  }

end