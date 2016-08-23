require "value"

type_test(AutoC::HashMap, :ValueHashMap, Value, Value) do
  
	def write_defs(stream)
		stream << %~
			#undef PUT
			#define PUT(t, k, v) {#{key.type} ek; #{value.type} ev; #{key.ctorEx}(ek, k); #{value.ctorEx}(ev, v); #{put}(t, ek, ev); #{key.dtor}(ek); #{value.dtor}(ev);}
		~
		super
	end

setup %~#{type} t;~
cleanup %~#{dtor}(&t);~

	test :create, %~
		#{ctor}(&t);
		TEST_EQUAL( #{size}(&t), 0 );
		TEST_TRUE( #{empty}(&t) );
	~

	test :purge, %~
		#{ctor}(&t);
		PUT(&t, 0, 0);
		TEST_FALSE( #{empty}(&t) );
		#{purge}(&t);
		TEST_TRUE( #{empty}(&t) );
	~

	test :empty, %~
		#{ctor}(&t);
		TEST_TRUE( #{empty}(&t) );
		PUT(&t, 1, -1);
		TEST_FALSE( #{empty}(&t) );
	~

	test :size, %~
		#{ctor}(&t);
		TEST_TRUE( #{empty}(&t) );
		TEST_EQUAL( #{size}(&t), 0 );
		PUT(&t, 1, -1);
		TEST_FALSE( #{empty}(&t) );
		TEST_EQUAL( #{size}(&t), 1 );
	~

setup %~
	/* {i => -i} */
	int i, c = 3;
	#{type} t;
	#{key.type} k;
	#{element.type} v;
	#{ctor}(&t);
	for(i = 1; i <= c; i++) {
		PUT(&t, i, -i);
	}
~
cleanup %~
	#{dtor}(&t);
~

	test :copy, %~
		#{type} t2;
		#{copy}(&t2, &t);
		TEST_TRUE( #{equal}(&t2, &t) );
		#{dtor}(&t2);
	~

	test :equal, %~
		#{type} t2;
		#{copy}(&t2, &t);
		TEST_TRUE( #{equal}(&t2, &t) );
		PUT(&t2, -1, 1);
		TEST_FALSE( #{equal}(&t2, &t) );
		#{dtor}(&t2);
	~

	test :containsKey, %~
		#{element.ctor(:k)};
		#{element.set}(k, 0);
		TEST_FALSE( #{containsKey}(&t, k) );
		#{element.set}(k, 1);
		TEST_TRUE( #{containsKey}(&t, k) );
		#{element.dtor(:k)};
	~

	test :get, %~
		#{element.ctor(:k)};
		#{element.set}(k, 3);
		TEST_TRUE( #{containsKey}(&t, k) );
		v = #{get}(&t, k);
		TEST_EQUAL( #{element.get}(v), -3 );
		#{element.dtor(:v)};
		#{element.dtor(:k)};
	~

	test :putNew, %~
		#{element.ctor(:k)};
		#{element.set}(k, 0);
		TEST_FALSE( #{containsKey}(&t, k) );
		TEST_TRUE( #{put}(&t, k, k) ) ;
		#{element.dtor(:k)};
	~

	test :putExisting, %~
		#{element.ctor(:k)};
		#{element.set}(k, 1);
		TEST_TRUE( #{containsKey}(&t, k) );
		TEST_FALSE( #{put}(&t, k, k) ) ;
		#{element.dtor(:k)};
	~

	test :remove, %~
		#{element.ctor(:k)};
		#{element.set}(k, 1);
		TEST_TRUE( #{containsKey}(&t, k) );
		TEST_TRUE( #{remove}(&t, k) ) ;
		TEST_FALSE( #{containsKey}(&t, k) );
		#{element.dtor(:k)};
	~

	test :removeNone, %~
		#{element.ctor(:k)};
		#{element.set}(k, 0);
		TEST_FALSE( #{containsKey}(&t, k) );
		TEST_FALSE( #{remove}(&t, k) ) ;
		TEST_FALSE( #{containsKey}(&t, k) );
		#{element.dtor(:k)};
	~

	test :replace, %~
		#{element.ctor(:k)};
		#{element.set}(k, 1);
		TEST_TRUE( #{containsKey}(&t, k) );
		TEST_TRUE( #{replace}(&t, k, k) ) ;
		TEST_TRUE( #{containsKey}(&t, k) );
		#{element.dtor(:k)};
	~

	test :replaceNone, %~
		#{element.ctor(:k)};
		#{element.set}(k, 0);
		TEST_FALSE( #{containsKey}(&t, k) );
		TEST_FALSE( #{replace}(&t, k, k) ) ;
		TEST_FALSE( #{containsKey}(&t, k) );
		#{element.dtor(:k)};
	~

	test :iterate, %~
		#{it} it;
		#{itCtor}(&it, &t);
		while(#{itMove}(&it)) {
			#{key.type} k;
			#{element.type} v;
			k = #{itGetKey}(&it);
			v = #{itGetElement}(&it);
			TEST_EQUAL( #{key.get}(k), -#{value.get}(v) );
			#{key.dtor}(k);
			#{value.dtor}(v);
		}
	~

end