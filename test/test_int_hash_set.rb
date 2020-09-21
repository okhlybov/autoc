require 'autoc/hash_set'

type_test(AutoC::HashSet, :IntHashSet, :int) do

  setup %$
    #{type} t;
    #{create}(&t);
  $

  cleanup %$
    #{destroy}(&t);
  $

  test :create, %$
    TEST_EQUAL( #{size}(&t), 0 );
  $

end