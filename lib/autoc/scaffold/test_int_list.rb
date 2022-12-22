require 'autoc/list'

[
	[:IntListDefault, :int, {}],
	[:IntListComputedSize, :int, { maintain_size: false }]
].each do |n, e, kws|

	type_test(AutoC::List, n, e, **kws) do

		###

		setup %{
			#{self} t;
		}

		cleanup %{
			#{destroy}(&t);
		}

		test :create, %{
			#{create}(&t);
			TEST_TRUE( #{empty}(&t) );
			TEST_EQUAL( #{size}(&t), 0 );
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