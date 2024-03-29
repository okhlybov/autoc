require 'autoc/hash_map'
require 'autoc/treap_map'
require 'autoc/intrusive_hash_map'

class V2IntrusiveHashMap < AutoC::IntrusiveHashMap
  def configure
    super
		tag_empty.code %{slot->index.value = (int*)1;}
		tag_deleted.code %{slot->index.value =(int*)2;}
		is_empty.code %{return slot->index.value == (int*)1;}
		is_deleted.code %{return slot->index.value == (int*)2;}
  end
end

[[AutoC::HashMap, :V2HashMap], [AutoC::TreapMap, :V2TreapMap], [V2IntrusiveHashMap, :V2IntrusiveHashMap]].each do |type, name|
  type_test(type, name, Value, Value) do

    ###

    setup %{
      #{self} t;
    }

    cleanup %{
      #{destroy}(&t);
    }

    test :create_empty, %{
      #{default_create.(:t)};
    }

    ###

    setup %{
      #{self} t;
      #{element} e;
      #{default_create.(:t)};
      TEST_TRUE( #{empty.(:t)} );
      TEST_EQUAL( #{size.(:t)}, 0 );
      #{element.custom_create.(:e, -1)};
    }

    cleanup %{
      #{destroy.(:t)};
      #{element.destroy.(:e)};
    }

    test :put_single_identity, %{
      #{set.(:t, :e, :e)};
      TEST_FALSE( #{empty.(:t)} );
      TEST_EQUAL( #{size.(:t)}, 1 );
    }

    test :put_repeated_identity, %{
      #{set.(:t, :e, :e)};
      #{set.(:t, :e, :e)};
      TEST_FALSE( #{empty.(:t)} );
      TEST_EQUAL( #{size.(:t)}, 1 );
    }

    ###

    setup %{
      #{self} t;
      #{element} e1, e2;
      #{default_create.(:t)};
      TEST_TRUE( #{empty.(:t)} );
      TEST_EQUAL( #{size.(:t)}, 0 );
      #{element.custom_create.(:e1, -1)};
      #{element.custom_create.(:e2, +1)};
      #{set.(:t, :e1, :e2)};
      TEST_EQUAL( #{size.(:t)}, 1 );
    }
    
    cleanup %{
      #{destroy.(:t)};
      #{element.destroy.(:e1)};
      #{element.destroy.(:e2)};
    }

    test :view_contains, %{
      TEST_TRUE( #{contains.(:t, :e2)} );
      TEST_FALSE( #{contains.(:t, :e1)} );
      TEST_FALSE( #{empty.(:t)} );
      TEST_EQUAL( #{size.(:t)}, 1 );
    }

    test :remove, %{
      TEST_TRUE( #{contains.(:t, :e2)} );
      TEST_FALSE( #{contains.(:t, :e1)} );
      TEST_FALSE( #{remove.(:t, :e2)} );
      TEST_TRUE( #{remove.(:t, :e1)} );
      TEST_TRUE( #{empty.(:t)} );
    }

  end
end