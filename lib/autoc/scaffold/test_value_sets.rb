require 'autoc/hash_set'
require 'autoc/treap_set'

[[AutoC::HashSet, :ValueHashSet], [AutoC::TreapSet, :ValueTreapSet]].each do |type, name|
  type_test(type, name, Value) do

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

    ###

    setup %{
      #{self} t;
      #{default_create}(&t);
    }

    cleanup %{
      #{destroy}(&t);
    }

    test :put, %{
      #{element} e;
      #{element.create}(&e);
      TEST_TRUE( #{put}(&t, e) );
      TEST_EQUAL( #{size}(&t), 1 );
      TEST_FALSE( #{put}(&t, e) );
      TEST_EQUAL( #{size}(&t), 1 );
      #{element.destroy}(&e);
    }

    test :push, %{
      #{element} e1, e2;
      #{element.create}(&e1);
      #{element.set}(&e2, -1);
      TEST_FALSE( #{push}(&t, e1) );
      TEST_EQUAL( #{size}(&t), 1 );
      TEST_FALSE( #{push}(&t, e2) );
      TEST_EQUAL( #{size}(&t), 2 );
      TEST_TRUE( #{push}(&t, e1) );
      TEST_EQUAL( #{size}(&t), 2 );
      #{element.destroy}(&e1);
      #{element.destroy}(&e2);
    }
    
  end
end