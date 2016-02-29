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

  test :hash, %~
    #{ctor}(&t, "XYZ");
    #{identify}(&t);
  ~
  
  test :within, %~
    #{ctor}(&t, "XYZ");
    TEST_FALSE( #{empty}(&t) );
    TEST_TRUE( #{within}(&t, 0) );
    TEST_TRUE( #{within}(&t, 2) );
    TEST_FALSE( #{within}(&t, 3) );
  ~
  
  test :withinNULLString, %~
    #{ctor}(&t, NULL);
    TEST_TRUE( #{empty}(&t) );
    TEST_FALSE( #{within}(&t, 0) );
    TEST_FALSE( #{within}(&t, 1) );
  ~

  test :withinEmptyString, %~
    #{ctor}(&t, "");
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
  
  test :pushChars, %~
    #{ctor}(&t, "X");
    #{pushChars}(&t, "Y");
    #{pushChars}(&t, "Z");
    TEST_EQUAL_CHARS( #{chars}(&t), "XYZ" );
  ~
  
  test :pushEmptyChars, %~
    #{ctor}(&t, "XYZ");
    #{pushChars}(&t, "");
    TEST_EQUAL_CHARS( #{chars}(&t), "XYZ" );
  ~
  
  test :pushCharsToNULL, %~
    #{ctor}(&t, NULL);
    #{pushChars}(&t, "XY");
    #{pushChars}(&t, "Z");
    TEST_EQUAL_CHARS( #{chars}(&t), "XYZ" );
  ~
  
  test :pushCharsToEmpty, %~
    #{ctor}(&t, "");
    #{pushChars}(&t, "X");
    #{pushChars}(&t, "YZ");
    TEST_EQUAL_CHARS( #{chars}(&t), "XYZ" );
  ~
  
  test :pushString, %~
    #{type} s;
    #{ctor}(&s, "YZ");
    #{ctor}(&t, "X");
    #{pushString}(&t, &s);
    TEST_EQUAL_CHARS( #{chars}(&t), "XYZ" );
    #{dtor}(&s);
  ~
  
  test :pushChar, %~
    #{ctor}(&t, "XY");
    #{pushChar}(&t, 'Z');
    TEST_EQUAL_CHARS( #{chars}(&t), "XYZ" );
  ~
  
  test :pushInt, %~
    #{ctor}(&t, "XYZ");
    #{pushInt}(&t, -123);
    TEST_EQUAL_CHARS( #{chars}(&t), "XYZ-123" );
  ~
  
  test :pushFloat, %~
    #{ctor}(&t, "XYZ");
    #{pushFloat}(&t, -1.23);
  ~

  test :pushPtr, %~
    #{ctor}(&t, "XYZ");
    #{pushPtr}(&t, &t);
  ~
  
  test :pushNULLPtr, %~
    #{ctor}(&t, "XYZ");
    #{pushPtr}(&t, NULL);
  ~
  
  test :pushFormat, %~
    #{ctor}(&t, NULL);
    #{pushFormat}(&t, "%s%c%d", "XY", 'Z', -123);
    TEST_EQUAL_CHARS( #{chars}(&t), "XYZ-123" );
  ~
  
  setup %~
    #{type} t;
    #{char_type}* b = #{malloc}(#{_bufferSize}*sizeof(#{char_type})); #{assert}(b);
    memset(b, '*', _#{bufferSize});
    b[#{_bufferSize}-1] = '\\0';
  ~
  cleanup %~
    #{free}(b);
    #{dtor}(&t);
  ~
  
  test :pushFormatExactBuffer, %~
    #{ctor}(&t, NULL);
    #{pushFormat}(&t, "%s", b);
    TEST_EQUAL_CHARS( #{chars}(&t), b );
  ~

  test :pushFormatOverBuffer, %~
    #{ctor}(&t, "-");
    #ifdef AUTOC_VSNPRINTF
      #{pushFormat}(&t, "%s-", b);
      TEST_EQUAL(#{size}(&t), #{_bufferSize}+1);
    #else
      TEST_MESSAGE("vsnprintf() is not used, skipping")
    #endif
  ~
    
setup %~
  #{type} t;
  #{it} it;
~
cleanup %~#{dtor}(&t);~

  test :iterateOverNULL, %~
    #{ctor}(&t, NULL);
    #{itCtor}(&it, &t);
    TEST_FALSE( #{itMove}(&it) );
  ~
  
  test :iterateOverEmpty, %~
    #{ctor}(&t, "");
    #{itCtor}(&it, &t);
    TEST_FALSE( #{itMove}(&it) );
  ~
  
  test :iterateForward, %~
    #{ctor}(&t, "XYZ");
    #{itCtor}(&it, &t);
    TEST_TRUE( #{itMove}(&it) );
    TEST_EQUAL( #{itGet}(&it), 'X' );
    TEST_TRUE( #{itMove}(&it) );
    TEST_EQUAL( #{itGet}(&it), 'Y' );
    TEST_TRUE( #{itMove}(&it) );
    TEST_EQUAL( #{itGet}(&it), 'Z' );
    TEST_FALSE( #{itMove}(&it) );
  ~
  
  test :iterateBackward, %~
    #{ctor}(&t, "ZYX");
    #{itCtorEx}(&it, &t, 0);
    TEST_TRUE( #{itMove}(&it) );
    TEST_EQUAL( #{itGet}(&it), 'X' );
    TEST_TRUE( #{itMove}(&it) );
    TEST_EQUAL( #{itGet}(&it), 'Y' );
    TEST_TRUE( #{itMove}(&it) );
    TEST_EQUAL( #{itGet}(&it), 'Z' );
    TEST_FALSE( #{itMove}(&it) );
  ~

setup %~#{type} t1, t2;~
cleanup %~#{dtor}(&t1); #{dtor}(&t2);~
  
  test :copy, %~
    #{ctor}(&t1, "XYZ");
    #{copy}(&t2, &t1);
    TEST_TRUE( #{equal}(&t1, &t2) );
  ~
  
  test :copyNULL, %~
    #{ctor}(&t1, NULL);
    #{copy}(&t2, &t1);
    TEST_TRUE( #{equal}(&t1, &t2) );
  ~
  
  test :copyEmpty, %~
    #{ctor}(&t1, "");
    #{copy}(&t2, &t1);
    TEST_TRUE( #{equal}(&t1, &t2) );
  ~
  
  test :copyFullRange, %~
    #{ctor}(&t1, "XYZ");
    #{copyRange}(&t2, &t1, 0, 2);
    TEST_TRUE( #{equal}(&t1, &t2) );
  ~
  
  test :copyPartialRange, %~
    #{ctor}(&t1, "_XYZ_");
    #{copyRange}(&t2, &t1, 1, 3);
    TEST_EQUAL_CHARS( #{chars}(&t2), "XYZ" );
  ~
  
  test :copySingleCharRange, %~
    #{ctor}(&t1, "XYZ");
    #{copyRange}(&t2, &t1, 1, 1);
    TEST_EQUAL_CHARS( #{chars}(&t2), "Y" );
  ~
  
  test :equal, %~
    #{ctor}(&t1, "XYZ");
    #{ctor}(&t2, "XYZ");
    TEST_TRUE( #{equal}(&t1, &t2) );
  ~
  
  test :notEqual, %~
    #{ctor}(&t1, "-XYZ");
    #{ctor}(&t2, "XYZ-");
    TEST_FALSE( #{equal}(&t1, &t2) );
  ~
  
end