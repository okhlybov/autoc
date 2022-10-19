require 'autoc/string'

type_test(AutoC::CString) do

  setup %{#{type} s;}
  cleanup %{#{destroy(:s)};}

  test :create_empty, %{
    #{custom_create(:s, %{""})};
    TEST_EQUAL( #{size(:s)}, 0 );
  }

  test :create_non_nempty, %{
    #{custom_create(:s, %{"hello"})};
    TEST_EQUAL( #{size(:s)}, 5 );
  }

  test :equal_cstr, %{
    #{custom_create(:s, %{"hello"})};
    TEST_TRUE( #{equal(:s, %{"hello"})} );
  }

  test :compare_cstr, %{
    #{custom_create(:s, %{"hello"})};
    TEST_FALSE( #{equal(%{"hello1"}, :s)} );
    TEST_FALSE( #{equal(:s, %{"hello1"})} );
    TEST_TRUE( #{compare(:s, %{"hello1"})} < 0 );
    TEST_TRUE( #{compare(%{"hello1"}, :s)} > 0 );
  }

  setup %{#{type} s1, s2;}
  cleanup %{#{destroy(:s1)}; #{destroy(:s2)};}

  test :compare_equal, %{
    #{custom_create(:s1, %{"autoc"})};
    #{custom_create(:s2, %{"autoc"})};
    TEST_TRUE( #{equal(:s1, :s2)} );
    TEST_EQUAL( #{compare(:s1, :s2)}, 0 );
    TEST_EQUAL( #{hash_code(:s1)}, #{hash_code(:s2)} );
  }

  test :compare_non_equal, %{
    #{custom_create(:s1, %{"autoc1"})};
    #{custom_create(:s2, %{"autoc2"})};
    TEST_FALSE( #{equal(:s1, :s2)} );
    TEST_FALSE( #{equal(:s2, :s1)} );
    TEST_TRUE( #{compare(:s1, :s2)} < 0 );
    TEST_TRUE( #{compare(:s2, :s1)} > 0 );
  }

end