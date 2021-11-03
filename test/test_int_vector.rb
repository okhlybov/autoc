require 'autoc/vector'

type_test(AutoC::Vector, :IntVector, :int) do

  setup %$
    #{type} t;
  $
  cleanup %$
    #{destroy}(&t);
  $

  test :create, %$
    #{default_create(:t)};
    TEST_EQUAL( #{size}(&t), 0 );
  $

  test :create_ex, %$
    #{custom_create(:t, 100)};
    TEST_EQUAL( #{size}(&t), 100 );
  $

  setup %$
    #{type} t1, t2;
    int i, c = 3;
    #{custom_create(:t1, :c)};
    #{custom_create(:t2, :c)};
    TEST_TRUE( #{equal(:t1, :t2)} );
    for(i = 0; i < c; ++i) {
      #{set}(&t1, i, i);
      #{set}(&t2, i, i);
    }
    TEST_TRUE( #{equal(:t1, :t2)} );
  $
  cleanup %$
    #{destroy}(&t1);
    #{destroy}(&t2);
  $

  test :sort, %$
    #{sort}(&t2, -1);
    /* 2,1,0 */
    TEST_FALSE( #{equal(:t1, :t2)} );
    TEST_EQUAL( #{get}(&t2, 0), 2 );
    TEST_EQUAL( #{get}(&t2, 1), 1 );
    #{sort}(&t2, 1);
    /* 0,1,2 */
    TEST_TRUE( #{equal(:t1, :t2)} );
    TEST_EQUAL( #{get}(&t2, 0), 0 );
    TEST_EQUAL( #{get}(&t2, 1), 1 );
  $

end