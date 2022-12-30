require 'autoc/cstring'

CString = type_test(AutoC::CString,  :CString) do

  ###

  setup %{
    #{self} s;
  }

  cleanup %{
    #{destroy.(:s)};
  }

  test :create_empty, %{
    #{custom_create.(:s, %{""})};
    TEST_EQUAL( #{size.(:s)}, 0 );
    TEST_TRUE( #{empty}(s) );
  }

  test :create_non_empty, %{
    #{custom_create.(:s, %{"hello"})};
    TEST_EQUAL( #{size.(:s)}, 5 );
  }

  test :format_empty, %{
    TEST_TRUE( #{create_format.(:s, %{""})} );
    TEST_TRUE( #{empty}(s) );
  }

  test :format_empty_params, %{
    TEST_TRUE( #{create_format.(:s, %{"hello"})} );
    TEST_TRUE( #{equal}(s, "hello") );
    TEST_FALSE( #{empty}(s) );
  }
  
  test :format_int, %{
    TEST_TRUE( #{create_format.(:s, %{"hello%d"}, -3)} );
    TEST_TRUE( #{equal}("hello-3", s) );
  }

  test :equal_cstr, %{
    #{custom_create.(:s, %{"hello"})};
    TEST_TRUE( #{equal.(:s, %{"hello"})} );
  }

  test :compare_cstr, %{
    #{custom_create.(:s, %{"hello"})};
    TEST_FALSE( #{equal.(%{"hello1"}, :s)} );
    TEST_FALSE( #{equal.(:s, %{"hello1"})} );
    TEST_TRUE( #{compare.(:s, %{"hello1"})} < 0 );
    TEST_TRUE( #{compare.(%{"hello1"}, :s)} > 0 );
  }

  ###

  setup %{
    #{self} s1, s2;
  }

  cleanup %{
    #{destroy.(:s1)};
    #{destroy.(:s2)};
  }

  test :compare_equal, %{
    #{custom_create.(:s1, %{"hello"})};
    #{custom_create.(:s2, %{"hello"})};
    TEST_TRUE( #{equal.(:s1, :s2)} );
    TEST_EQUAL( #{compare.(:s1, :s2)}, 0 );
    TEST_EQUAL( #{hash_code.(:s1)}, #{hash_code.(:s2)} );
  }

  test :compare_non_equal, %{
    #{custom_create.(:s1, %{"hello1"})};
    #{custom_create.(:s2, %{"hello2"})};
    TEST_FALSE( #{equal.(:s1, :s2)} );
    TEST_FALSE( #{equal.(:s2, :s1)} );
    TEST_TRUE( #{compare.(:s1, :s2)} < 0 );
    TEST_TRUE( #{compare.(:s2, :s1)} > 0 );
  }

  ###

  setup %{
    #{self} s;
    #{custom_create.(:s, %{"hello"})};
  }

  cleanup %{
    #{destroy.(:s)};
  }

  test :char_access, %{
    TEST_EQUAL( #{get.(:s, 0)}, 'h' );
    TEST_EQUAL( *#{view}(s, 4), 'o' );
  }

  test :range_access, %{
    #{range} r = #{range.new.(:s)};
    TEST_EQUAL( #{size}(s), 5 );
    TEST_EQUAL( #{range.size}(&r), #{size}(s) );
    TEST_EQUAL( #{range.take_front}(&r), 'h' );
    TEST_EQUAL( *#{range.view_back}(&r), 'o' );
    #{range.pop_front}(&r);
    TEST_EQUAL( *#{range.view_front}(&r), 'e' );
    TEST_EQUAL( #{range.size}(&r), #{size}(s)-1 );
    #{range.pop_back}(&r);
    TEST_EQUAL( #{range.take_back}(&r), 'l' );
    TEST_EQUAL( #{range.size}(&r), #{size}(s)-2 );
  }
  
end