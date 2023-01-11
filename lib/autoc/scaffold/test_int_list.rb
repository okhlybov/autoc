require 'autoc/list'

[
	[:IntListDefault, :int, {}],
	[:IntListComputedSize, :int, { maintain_size: false }]
].each do |n, e, kws|

	type_test(AutoC::List, n, e, **kws) do

		###

		setup %{
			#{self} t;
			#{create}(&t);
		}

		cleanup %{
			#{destroy}(&t);
		}

		test :create, %{
			TEST_TRUE( #{empty}(&t) );
			TEST_EQUAL( #{size}(&t), 0 );
		}

		test :copy_empty, %{
			#{self} r;
			#{copy}(&r, &t);
			TEST_TRUE( #{equal}(&r, &t) );
			#{destroy}(&r);
		}

		test :copy, %{
			#{self} r;
			#{push_front}(&t, 1);
			#{push_front}(&t, 2);
			#{push_front}(&t, 3);
			#{copy}(&r, &t);
			TEST_TRUE( #{equal}(&r, &t) );
			#{destroy}(&r);
		}

		###

		setup %{
			#{self} t;
			#{create}(&t);
			#{push_front}(&t, 1);
			#{push_front}(&t, 2);
			#{push_front}(&t, 3);
		}

		cleanup %{
			#{destroy}(&t);
		}

		test :remove_none, %{
			TEST_FALSE( #{remove_first.(:t, 4)} );
			TEST_EQUAL( #{size.(:t)}, 3 );
		}

		test :remove_front, %{
			TEST_TRUE( #{remove_first.(:t, 3)} );
			TEST_EQUAL( #{size.(:t)}, 2 );
			TEST_EQUAL( #{take_front.(:t)}, 2 );
		}

		test :remove_back, %{
			TEST_TRUE( #{remove_first.(:t, 1)} );
			TEST_EQUAL( #{size.(:t)}, 2 );
		}

		test :remove_middle, %{
			TEST_TRUE( #{remove_first.(:t, 2)} );
			TEST_EQUAL( #{size.(:t)}, 2 );
		}

		###
		
		setup %{
			int i, c = 3;
			#{self} t1, t2;
			#{create}(&t1);
			#{create}(&t2);
			for(i = 0; i < c; ++i) {
				#{push_front}(&t1, i);
				#{push_front}(&t2, i);
			}
		}

		cleanup %{
			#{destroy}(&t1);
			#{destroy}(&t2);
		}

		test :equal, %{
			TEST_EQUAL( #{size}(&t1), #{size}(&t2) );
			TEST_TRUE( #{equal}(&t1, &t2) );
			#{push_front}(&t2, -1);
			TEST_NOT_EQUAL( #{size}(&t1), #{size}(&t2) );
			TEST_FALSE( #{equal}(&t1, &t2) );
		}

	end

end