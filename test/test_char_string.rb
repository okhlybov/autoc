type_test(AutoC::String, :CharString) do

setup %~#{type} t;~
cleanup %~#{dtor}(&t);~
  
  test :create, %~
    #{ctor}(&t, "XYZ");
  ~
  
  test :createWithNULL, %~
    #{ctor}(&t, NULL);
    TEST_TRUE( #{empty}(&t) );
  ~
  
  test :createWithEmptyChars, %~
    #{ctor}(&t, "");
    TEST_TRUE( #{empty}(&t) );
  ~

  test :within, %~
    #{ctor}(&t, "XYZ");
    TEST_FALSE( #{empty}(&t) );
    TEST_TRUE( #{within}(&t, 0) );
    TEST_TRUE( #{within}(&t, 2) );
    TEST_FALSE( #{within}(&t, 3) );
  ~
  
  test :withinEmptyString, %~
    #{ctor}(&t, NULL);
    TEST_TRUE( #{empty}(&t) );
    TEST_FALSE( #{within}(&t, 0) );
    TEST_FALSE( #{within}(&t, 1) );
  ~

  test :stringSize, %~
    #{ctor}(&t, "XYZ");
    TEST_EQUAL( #{size}(&t), 3 );
  ~

  test :emptyStringSize, %~
    #{ctor}(&t, "");
    TEST_TRUE( #{empty}(&t) );
    TEST_EQUAL( #{size}(&t), 0 );
  ~
  
  test :NULLStringSize, %~
    #{ctor}(&t, NULL);
    TEST_TRUE( #{empty}(&t) );
    TEST_EQUAL( #{size}(&t), 0 );
  ~
  
  test :chars, %~
    #{ctor}(&t, "XYZ");
    TEST_EQUAL_CHARS( #{chars}(&t), "XYZ" );
    TEST_NOT_EQUAL_CHARS( #{chars}(&t), "xyz" );
  ~
  
  test :getChar, %~
    #{ctor}(&t, "XYZ");
    TEST_EQUAL( #{get}(&t, 2), 'Z' );
  ~
  
  test :setChar, %~
    #{ctor}(&t, "XYZ");
    TEST_NOT_EQUAL( #{get}(&t, 0), 'x' );
    #{set}(&t, 0, 'x');
    TEST_EQUAL( #{get}(&t, 0), 'x' );
  ~
  
end