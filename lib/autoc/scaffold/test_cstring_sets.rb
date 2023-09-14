require 'autoc/hash_set'
require 'autoc/treap_set'

require_relative 'test_cstring'

[[AutoC::HashSet, :CStringHashSet], [AutoC::TreapSet, :CStringTreapSet]].each do |type, name|
  type_test(type, name, CString) do

    ###

    setup %{
      #{self} t;
    }

    cleanup %{
      #{destroy}(&t);
    }

    test :create_default, %{
      #{default_create}(&t);
      TEST_EQUAL( #{size}(&t), 0 );
    }

    if type == AutoC::HashSet
      test :create_custom, %{
        #{create_capacity}(&t, 1024);
        TEST_EQUAL( #{size}(&t), 0 );
      }
    end

    test :put, %{
      #{default_create}(&t);
      #{put}(&t, "kitty");
      #{put}(&t, "hello");
      #{put}(&t, "kitty");
      TEST_EQUAL( #{size}(&t), 2 );
    }

  end
end