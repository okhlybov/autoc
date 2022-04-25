require 'autoc/hash_set'
require 'autoc/structure'

type_test(AutoC::HashSet, :XYHashSet, AutoC::Structure.new(:XY, { x: :int, y: :int }, profile: :blackbox)) do

  #

  setup %{ #{type} t; }
  cleanup %{ #{destroy}(&t); }

  test :create_default, %{
    #{default_create}(&t);
    TEST_EQUAL( #{size}(&t), 0 );
  }

  test :create_custom, %{
    #{create_capacity}(&t, 1024, 1);
    TEST_EQUAL( #{size}(&t), 0 );
  }

  #

  setup %{ #{type} t; #{default_create}(&t); }
  cleanup %{ #{destroy}(&t); }

  test :put, %{
    #{put}(&t, (XY){0,1});
    #{put}(&t, (XY){1,0});
    TEST_EQUAL( #{size}(&t), 2 );
  }
end