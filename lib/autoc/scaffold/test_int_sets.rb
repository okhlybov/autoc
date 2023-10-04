require 'autoc/hash_set'
require 'autoc/treap_set'
require 'autoc/intrusive_hash_set'

class IntrusiveIntHashSet < AutoC::IntrusiveHashSet
  def configure
    super
    mark.code %{
      switch(state) {
        case #{_EMPTY}: slot->element = INT_MAX; break;
        case #{_DELETED}: slot->element = INT_MIN; break;
      }
    }
    marked.code %{
      switch(slot->element) {
        case INT_MAX: return #{_EMPTY};
        case INT_MIN: return #{_DELETED};
        default: return 0;
      }
    }
  end
end

[[AutoC::HashSet, :IntHashSet], [AutoC::TreapSet, :IntTreapSet], [IntrusiveIntHashSet, :IntrusiveIntHashSet]].each do |type, name|
	type_test(type, name, :int) do

		###

		def render_forward_declarations(stream)
			super
			stream << "void #{dump}(#{const_rvalue} target);"
		end

		def render_implementation(stream)
			super
			stream << %{
				#include <stdio.h>
				void #{dump}(#{const_rvalue} target) {
					#{range} r;
					for(r = #{range.new}(target); !#{range.empty}(&r); #{range.pop_front}(&r)) {
						printf("%d ", #{range.take_front}(&r));
					}
					printf("\\n");
				}
			}
		end

		setup %{
			#{self} t;
		}

		cleanup %{
			#{destroy}(&t);
		}

		test :create_empty, %{
			#{create}(&t);
			TEST_TRUE( #{empty}(&t) );
			TEST_EQUAL( #{size}(&t), 0 );
		}

		test :iterate_0, %{
			#{create}(&t);
			#{range} r = #{range.new}(&t);
			TEST_TRUE( #{range.empty}(&r) );
		}

		test :iterate_1, %{
			#{create}(&t);
			TEST_EQUAL( #{size}(&t), 0 );
			#{put}(&t, -3);
			TEST_EQUAL( #{size}(&t), 1 );
			#{range} r = #{range.new}(&t);
			TEST_FALSE( #{range.empty}(&r) );
			TEST_EQUAL( #{range.take_front}(&r), -3 );
			#{range.pop_front}(&r);
			TEST_TRUE( #{range.empty}(&r) );
		}

		###

		setup %{
			int i;
			#{self} t;
			#{create}(&t);
			for(i = 0; i < 3; ++i) {
				#{put}(&t, i*11);
			}
		}

		cleanup %{
			#{destroy}(&t);
		}

		test :iterate_3, %{
			TEST_EQUAL( #{size}(&t), 3);
			#{range} r = #{range.new}(&t);
			TEST_FALSE( #{range.empty}(&r) );
			#{range.pop_front}(&r);
			TEST_FALSE( #{range.empty}(&r) );
			#{range.pop_front}(&r);
			TEST_FALSE( #{range.empty}(&r) );
			#{range.pop_front}(&r);
			TEST_TRUE( #{range.empty}(&r) );
		}

		###

		setup %{
			#{self} t;
			#{create}(&t);
		}

		cleanup %{
			#{destroy}(&t);
		}

		test :put_uniques, %{
			TEST_TRUE( #{put}(&t, 0) );
			TEST_TRUE( #{put}(&t, -1) );
			TEST_TRUE( #{put}(&t, 1) );
			TEST_EQUAL( #{size}(&t), 3 );
		}

		test :put_duplicates, %{
			TEST_TRUE( #{put}(&t, 0) );
			TEST_TRUE( #{put}(&t, -1) );
			TEST_TRUE( #{put}(&t, 1) );
			TEST_FALSE( #{put}(&t, 0) );
			TEST_FALSE( #{put}(&t, 1) );
			TEST_FALSE( #{put}(&t, -1) );
			TEST_EQUAL( #{size}(&t), 3 );
		}

		test :push, %{
			TEST_FALSE( #{push}(&t, 1) );
			TEST_FALSE( #{push}(&t, -1) );
			TEST_TRUE( #{push}(&t, 1) );
			TEST_EQUAL( #{size}(&t), 2 );
		}

		test :contains, %{
			TEST_FALSE( #{contains}(&t, -1) );
			TEST_TRUE( #{put}(&t, -1) );
			TEST_TRUE( #{contains}(&t, -1) );
		}

		###

		setup %{
			#{self} t, r;
			#{create}(&t);
			#{create}(&r);
		}

		cleanup %{
			#{destroy}(&t);
			#{destroy}(&r);
		}

		test :remove_empty, %{
			TEST_EQUAL( #{size}(&t), 0 );
			TEST_FALSE( #{remove}(&t, 0) );
			TEST_TRUE( #{equal}(&t, &r) );
			TEST_TRUE( #{equal}(&r, &t) );
		}

		test :remove_nonexistent, %{
			TEST_TRUE( #{put}(&t, 1) );
			TEST_TRUE( #{put}(&t, 2) );
			TEST_TRUE( #{put}(&t, 3) );
			TEST_TRUE( #{put}(&r, 1) );
			TEST_TRUE( #{put}(&r, 2) );
			TEST_TRUE( #{put}(&r, 3) );
			TEST_EQUAL( #{size}(&t), 3 );
			TEST_FALSE( #{remove}(&t, 0) );
			TEST_TRUE( #{equal}(&t, &r) );
			TEST_TRUE( #{equal}(&r, &t) );
		}

		test :remove, %{
			TEST_TRUE( #{put}(&t, 1) );
			TEST_TRUE( #{put}(&t, 2) );
			TEST_TRUE( #{put}(&t, 3) );
			TEST_TRUE( #{put}(&r, 1) );
			TEST_TRUE( #{put}(&r, 3) );
			TEST_EQUAL( #{size}(&t), 3 );
			TEST_TRUE( #{contains}(&t, 2) );
			TEST_TRUE( #{remove}(&t, 2) );
			TEST_FALSE( #{contains}(&t, 2) );
			TEST_TRUE( #{equal}(&t, &r) );
			TEST_TRUE( #{equal}(&r, &t) );
		}

		###

		setup %{
			#{self} t1, t2;
			#{create}(&t1);
			#{create}(&t2);
		}

		cleanup %{
			#{destroy}(&t1);
			#{destroy}(&t2);
		}

		test :equal_empty, %{
			TEST_EQUAL( #{size}(&t1), 0 );
			TEST_EQUAL( #{size}(&t2), 0 );
			TEST_TRUE( #{equal}(&t1, &t2) );
		}

		test :equal_one, %{
			TEST_TRUE( #{put}(&t1, 3) );
			TEST_TRUE( #{put}(&t2, 3) );
			TEST_EQUAL( #{size}(&t1), 1 );
			TEST_EQUAL( #{size}(&t2), 1 );
			TEST_TRUE( #{equal}(&t1, &t2) );
		}

		test :equal, %{
			TEST_TRUE( #{put}(&t1, 3) );
			TEST_TRUE( #{put}(&t1, -3) );
			TEST_TRUE( #{put}(&t1, 0) );
			TEST_TRUE( #{put}(&t2, -3) );
			TEST_TRUE( #{put}(&t2, 0) );
			TEST_TRUE( #{put}(&t2, 3) );
			TEST_EQUAL( #{size}(&t1), 3 );
			TEST_EQUAL( #{size}(&t2), 3 );
			TEST_TRUE( #{equal}(&t1, &t2) );
		}

		test :subset_empty, %{
			TEST_TRUE( #{equal}(&t1, &t2) );
			TEST_TRUE( #{subset}(&t1, &t1) );
			TEST_TRUE( #{subset}(&t2, &t2) );
			TEST_TRUE( #{subset}(&t1, &t2) );
			TEST_TRUE( #{subset}(&t2, &t1) );
		}

		test :subset_equal, %{
			TEST_TRUE( #{put}(&t1, 1) );
			TEST_TRUE( #{put}(&t1, 2) );
			TEST_TRUE( #{put}(&t1, 3) );
			TEST_TRUE( #{put}(&t2, 3) );
			TEST_TRUE( #{put}(&t2, 2) );
			TEST_TRUE( #{put}(&t2, 1) );
			/* t2 == t1 */
			TEST_TRUE( #{equal}(&t1, &t2) );
			TEST_TRUE( #{subset}(&t1, &t1) );
			TEST_TRUE( #{subset}(&t2, &t2) );
			TEST_TRUE( #{subset}(&t1, &t2) );
			TEST_TRUE( #{subset}(&t2, &t1) );
		}

		test :subset, %{
			TEST_TRUE( #{put}(&t1, 1) );
			TEST_TRUE( #{put}(&t1, 2) );
			TEST_TRUE( #{put}(&t1, 3) );
			TEST_TRUE( #{put}(&t2, 2) );
			TEST_TRUE( #{put}(&t2, 1) );
			/* t2 < t1 */
			TEST_FALSE( #{equal}(&t1, &t2) );
			TEST_TRUE( #{subset}(&t1, &t1) );
			TEST_TRUE( #{subset}(&t2, &t2) );
			TEST_FALSE( #{subset}(&t1, &t2) );
			TEST_TRUE( #{subset}(&t2, &t1) );
		}

		test :disjoint, %{
			TEST_TRUE( #{put}(&t1, 1) );
			TEST_TRUE( #{put}(&t1, 2) );
			TEST_TRUE( #{put}(&t1, 3) );
			TEST_TRUE( #{put}(&t2, -1) );
			TEST_TRUE( #{put}(&t2, -2) );
			TEST_TRUE( #{put}(&t2, -3) );
			TEST_FALSE( #{equal}(&t1, &t2) );
			TEST_TRUE( #{disjoint}(&t1, &t2) );
			TEST_TRUE( #{disjoint}(&t2, &t1) );
			TEST_TRUE( #{put}(&t1, 0) );
			TEST_TRUE( #{put}(&t2, 0) );
			TEST_FALSE( #{disjoint}(&t1, &t2) );
			TEST_FALSE( #{disjoint}(&t2, &t1) );
		}

		test :disjoint_equal, %{
			TEST_TRUE( #{put}(&t1, 1) );
			TEST_TRUE( #{put}(&t1, 2) );
			TEST_TRUE( #{put}(&t1, 3) );
			TEST_TRUE( #{put}(&t2, 1) );
			TEST_TRUE( #{put}(&t2, 2) );
			TEST_TRUE( #{put}(&t2, 3) );
			TEST_TRUE( #{equal}(&t1, &t2) );
			TEST_FALSE( #{disjoint}(&t1, &t2) );
			TEST_FALSE( #{disjoint}(&t2, &t1) );
		}

		test :disjoint_empty, %{
			TEST_TRUE( #{equal}(&t1, &t2) );
			TEST_TRUE( #{disjoint}(&t1, &t2) );
			TEST_TRUE( #{disjoint}(&t2, &t1) );
		}

		###

		setup %{
			#{self} t1, t2, r, t;
			#{create}(&t1);
			#{create}(&t2);
			#{create}(&r);
		}

		cleanup %{
			#{destroy}(&t1);
			#{destroy}(&t2);
			#{destroy}(&r);
			#{destroy}(&t);
		}

		test :join_empty, %{
			#{create_join}(&t, &t1, &t2);
			#{join}(&t1, &t2);
			TEST_TRUE( #{equal}(&r, &t1) );
			TEST_TRUE( #{equal}(&r, &t2) );
			TEST_TRUE( #{equal}(&r, &t) );
		}

		test :join, %{
			/* 1,2,3 */
			TEST_TRUE( #{put}(&r, 1) );
			TEST_TRUE( #{put}(&r, 2) );
			TEST_TRUE( #{put}(&r, 3) );
			/* 1,2 */
			TEST_TRUE( #{put}(&t1, 1) );
			TEST_TRUE( #{put}(&t1, 2) );
			/* 1,3 */
			TEST_TRUE( #{put}(&t2, 1) );
			TEST_TRUE( #{put}(&t2, 3) );
			#{create_join}(&t, &t1, &t2);
			#{join}(&t1, &t2); /* 1,2 | 1,3 -> 1,2,3 */
			TEST_TRUE( #{equal}(&r, &t1) );
			TEST_TRUE( #{equal}(&t1, &r) );
			TEST_FALSE( #{equal}(&r, &t2) );
			TEST_FALSE( #{equal}(&t2, &r) );
			TEST_TRUE( #{equal}(&t, &r) );
		}

		test :subtract, %{
			/* 0,2 */
			TEST_TRUE( #{put}(&r, 0) );
			TEST_TRUE( #{put}(&r, 2) );
			/* 0,1,2 */
			TEST_TRUE( #{put}(&t1, 0) );
			TEST_TRUE( #{put}(&t1, 1) );
			TEST_TRUE( #{put}(&t1, 2) );
			/* 1,3 */
			TEST_TRUE( #{put}(&t2, 1) );
			TEST_TRUE( #{put}(&t2, 3) );
			#{create_difference}(&t, &t1, &t2); /* 0,1,2 - 1,3 -> 0,2 */
			#{subtract}(&t1, &t2);
			TEST_TRUE( #{equal}(&r, &t1) );
			TEST_TRUE( #{equal}(&t1, &r) );
			TEST_FALSE( #{equal}(&r, &t2) );
			TEST_FALSE( #{equal}(&t2, &r) );
			TEST_TRUE( #{equal}(&t, &t1) );
		}

		test :intersect_disjoint, %{
			/* 1,2,3 */
			TEST_TRUE( #{put}(&t1, 1) );
			TEST_TRUE( #{put}(&t1, 2) );
			TEST_TRUE( #{put}(&t1, 3) );
			/* -1,-2,-3 */
			TEST_TRUE( #{put}(&t2, -1) );
			TEST_TRUE( #{put}(&t2, -2) );
			TEST_TRUE( #{put}(&t2, -3) );
			#{create_intersection}(&t, &t1, &t2);
			#{intersect}(&t1, &t2);
			TEST_TRUE( #{empty}(&t1) );
			TEST_TRUE( #{equal}(&r, &t1) );
			TEST_TRUE( #{equal}(&t1, &r) );
			TEST_TRUE( #{equal}(&t, &r) );
			TEST_TRUE( #{empty}(&t) );
		}

		test :intersect_equal, %{
			/* 1,2,3 */
			TEST_TRUE( #{put}(&t1, 1) );
			TEST_TRUE( #{put}(&t1, 2) );
			TEST_TRUE( #{put}(&t1, 3) );
			/* 1,2,3 */
			TEST_TRUE( #{put}(&t2, 3) );
			TEST_TRUE( #{put}(&t2, 2) );
			TEST_TRUE( #{put}(&t2, 1) );
			/* 1,2,3 */
			TEST_TRUE( #{put}(&r, 3) );
			TEST_TRUE( #{put}(&r, 2) );
			TEST_TRUE( #{put}(&r, 1) );
			#{create_intersection}(&t, &t1, &t2);
			#{intersect}(&t1, &t2); /* 1,2,3 & 1,2,3 -> 1,2,3 */
			TEST_TRUE( #{equal}(&r, &t1) );
			TEST_TRUE( #{equal}(&t1, &r) );
			TEST_TRUE( #{equal}(&r, &t2) );
			TEST_TRUE( #{equal}(&t2, &r) );
			TEST_TRUE( #{equal}(&t1, &t2) );
			TEST_TRUE( #{equal}(&t2, &t1) );
			TEST_TRUE( #{equal}(&t, &r) );
		}

		test :intersect, %{
			/* 0,1,2,3 */
			TEST_TRUE( #{put}(&t1, 1) );
			TEST_TRUE( #{put}(&t1, 2) );
			TEST_TRUE( #{put}(&t1, 3) );
			/* 0,-1,-2,-3 */
			TEST_TRUE( #{put}(&t2, -1) );
			TEST_TRUE( #{put}(&t2, -2) );
			TEST_TRUE( #{put}(&t2, -3) );
			TEST_TRUE( #{put}(&t1, 0) );
			TEST_TRUE( #{put}(&t2, 0) );
			TEST_TRUE( #{put}(&r, 0) );
			#{create_intersection}(&t, &t1, &t2);
			#{intersect}(&t1, &t2); /* 0,1,2,3  &  0,-1,-2,-3 -> 0 */
			TEST_TRUE( #{equal}(&r, &t1) );
			TEST_TRUE( #{equal}(&t1, &r) );
			TEST_FALSE( #{equal}(&r, &t2) );
			TEST_FALSE( #{equal}(&t2, &r) );
			TEST_TRUE( #{equal}(&r, &t) );
		}

		test :disjoin_disjoint, %{
			/* 1,2 */
			TEST_TRUE( #{put}(&t1, 1) );
			TEST_TRUE( #{put}(&t1, 2) );
			/* 3,4 */
			TEST_TRUE( #{put}(&t2, 4) );
			TEST_TRUE( #{put}(&t2, 3) );
			/* 1,2,3,4 */
			TEST_TRUE( #{put}(&r, 3) );
			TEST_TRUE( #{put}(&r, 1) );
			TEST_TRUE( #{put}(&r, 2) );
			TEST_TRUE( #{put}(&r, 4) );
			#{create_disjunction}(&t, &t2, &t1);
			#{disjoin}(&t1, &t2);
			TEST_TRUE( #{equal}(&r, &t1) ); /* 1,2 ^ 3,4 -> 1,2,3,4 */
			TEST_TRUE( #{equal}(&r, &t) );
		}

		test :disjoin, %{
			/* 1,2,-3 */
			TEST_TRUE( #{put}(&t1, -3) );
			TEST_TRUE( #{put}(&t1, 1) );
			TEST_TRUE( #{put}(&t1, 2) );
			/* 3,4, -3 */
			TEST_TRUE( #{put}(&t2, 4) );
			TEST_TRUE( #{put}(&t2, 3) );
			TEST_TRUE( #{put}(&t2, -3) );
			/* 1,2,3,4 */
			TEST_TRUE( #{put}(&r, 3) );
			TEST_TRUE( #{put}(&r, 1) );
			TEST_TRUE( #{put}(&r, 2) );
			TEST_TRUE( #{put}(&r, 4) );
			#{create_disjunction}(&t, &t2, &t1);
			#{disjoin}(&t1, &t2);
			TEST_TRUE( #{equal}(&r, &t1) ); /* 1,2, -3 ^ 3,4, -3 -> 1,2,3,4 */
			TEST_TRUE( #{equal}(&r, &t) );
		}

	end
end