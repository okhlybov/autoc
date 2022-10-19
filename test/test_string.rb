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

  test :equal_pchar, %{
    #{custom_create(:s, %{"hello"})};
    TEST_TRUE( #{equal}(&s, &"hello") );
  }
end