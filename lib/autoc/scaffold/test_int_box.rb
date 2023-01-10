require 'autoc/box'
require_relative 'test_int_vector'

type_test(AutoC::Box, :IntBox, { number: :int, numbers: IntVector }) do

  ###

  setup %{
    #{self} t;
    #{default_create.(:t)};
  }

  cleanup %{
    #{destroy.(:t)};
  }

  test :create_empty, %{
    #{purge.(:t)};
    TEST_FALSE( #{tag.(:t)} );
  }

end
