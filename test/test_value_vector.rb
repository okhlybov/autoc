require 'autoc/vector'
require 'value'


type_test(AutoC::Vector, :ValueVector, Value) do

  setup %~#{type} t;~

  cleanup %~#{destroy}(&t);~

  test :create_smallest, %~
    #{create_size}(&t, 1);
    TEST_EQUAL( #{size}(&t), 1 );
  ~

  test :create_large, %~
    #{create_size}(&t, 1024);
    TEST_EQUAL( #{size}(&t), 1024 );
  ~

  setup %~
    #{type} t;
    #{element.type} e;
    int i, c = 3;
    #{create_size}(&t, c);
    for(i = 0; i < c; ++i) {
      #{element.custom_create}(e, i);
      #{set}(&t, i, e);
      #{element.destroy}(e);
    }
  ~

  cleanup %~#{destroy}(&t);~

  test :get, %~
    #{element.type} e2;
    #{element.custom_create}(e, 2);
    e2 = #{get}(&t, 2);
    TEST_TRUE( #{element.equal}(e, e2) );
    #{element.destroy}(e);
    #{element.destroy}(e2);
  ~

  test :set, %~
    #{element.type} e2;
    #{element.custom_create}(e, -1);
    #{set}(&t, 2, e);
    e2 = #{get}(&t, 2);
    TEST_TRUE( #{element.equal}(e, e2) );
    #{element.destroy}(e);
    #{element.destroy}(e2);
  ~

  test :valid_position, %~
    TEST_TRUE( #{valid_position}(&t, 0) );
    TEST_TRUE( #{valid_position}(&t, 2) );
    TEST_FALSE( #{valid_position}(&t, 3) );
  ~

  test :iterate_forward, %~
    i = 0;
    #{range.type} it;
    for(#{range.create}(&it, &t); !#{range.empty}(&it); #{range.pop_front}(&it)) {
      e = #{range.front}(&it);
      TEST_EQUAL( ValueGet(e), i++ );
      #{element.destroy}(e);
    }
  ~

  test :iterate_backward, %~
    i = c-1;
    #{range.type} it;
    for(#{range.create}(&it, &t); !#{range.empty}(&it); #{range.pop_back}(&it)) {
      e = #{range.back}(&it);
      TEST_EQUAL( ValueGet(e), i-- );
      #{element.destroy}(e);
    }
  ~

  setup %~
    #{type} t1, t2;
    #{element.type} e;
    int i, c = 3;
    #{create_size}(&t1, c);
    #{create_size}(&t2, c);
    TEST_TRUE( #{equal}(&t1, &t2) );
    for(i = 0; i < c; ++i) {
      #{element.custom_create}(e, i);
      #{set}(&t1, i, e);
      #{set}(&t2, i, e);
      #{element.destroy}(e);
    }
    TEST_TRUE( #{equal}(&t1, &t2) );
  ~

  cleanup %~
    #{destroy}(&t1);
    #{destroy}(&t2);
  ~
  
    test :size, %~
      TEST_EQUAL( #{size}(&t1), 3 );
      TEST_EQUAL( #{size}(&t1), #{size}(&t2) );
      #{resize}(&t2, 1);
      TEST_EQUAL( #{size}(&t2), 1 );
      TEST_NOT_EQUAL( #{size}(&t1), #{size}(&t2) );
    ~
  
    test :equal, %~
      #{element.custom_create}(e, -1);
      #{set}(&t1, 0, e);
      #{element.destroy}(e);
      TEST_FALSE( #{equal}(&t1, &t2) );
    ~
  
    test :resize_shrink, %~
      #{resize}(&t2, 2);
      TEST_EQUAL( #{size}(&t2), 2 );
      TEST_FALSE( #{equal}(&t1, &t2) );
    ~
  
    test :resize_expand, %~
      #{resize}(&t2, 4);
      TEST_EQUAL( #{size}(&t2), 4 );
      TEST_FALSE( #{equal}(&t1, &t2) );
      e = #{get}(&t2, 3);
      TEST_EQUAL( ValueGet(e), 0 );
      TEST_NOT_EQUAL( ValueGet(e), 1 );
      #{element.destroy}(e);
    ~
  
    test :sort, %~
      #{sort}(&t2, +1);
      TEST_TRUE( #{equal}(&t1, &t2) );
      e = #{get}(&t2, 0);
      TEST_EQUAL( ValueGet(e), 0 );
      #{element.destroy}(e);
      #{sort}(&t2, -1);
      TEST_FALSE( #{equal}(&t1, &t2) );
      e = #{get}(&t2, 0);
      TEST_EQUAL( ValueGet(e), 2 );
      #{element.destroy}(e);
    ~

  end