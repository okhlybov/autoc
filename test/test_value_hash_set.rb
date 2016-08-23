require "value"

type_test(AutoC::HashSet, :ValueHashSet, Value) do
  
	def write_defs(stream)
		stream << %~
			#undef PUT
			#define PUT(t, v) {#{element.type} e; #{element.ctorEx}(e, v); #{put}(t, e); #{element.dtor}(e);}
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
		PUT(&t, 0);
		TEST_FALSE( #{empty}(&t) );
		#{purge}(&t);
		TEST_TRUE( #{empty}(&t) );
	~

setup %~
	/* a: [1,2,3], e: 0 */
	#{type} a;
	#{element.type} e;
	#{element.ctor(:e)};
	#{ctor}(&a);
	PUT(&a, 1); PUT(&a, 2); PUT(&a, 3);
~
cleanup %~
	#{dtor}(&a);
	#{element.dtor(:e)};
~

	test :contains, %~
		TEST_FALSE( #{contains}(&a, e) );
		#{element.set}(e, 1);
		TEST_TRUE( #{contains}(&a, e) );
	~

	test :get, %~
		#{element.type} e2;
		#{element.set}(e, -1);
		#{put}(&a, e);
		e2 = #{get}(&a, e);
		TEST_TRUE( #{element.equal}(e, e2) );
		#{element.dtor(:e2)};
	~

	test :putNew, %~
		#{element.set}(e, -1);
		TEST_FALSE( #{contains}(&a, e) );
		TEST_TRUE( #{put}(&a, e) );
		TEST_TRUE( #{contains}(&a, e) );
	~

	test :putExisting, %~
		#{element.set}(e, -1);
		TEST_FALSE( #{contains}(&a, e) );
		TEST_TRUE( #{put}(&a, e) );
		TEST_TRUE( #{contains}(&a, e) );
		TEST_FALSE( #{put}(&a, e) );
	~

	test :replace, %~
		#{element.set}(e, 1);
		TEST_TRUE( #{contains}(&a, e) );
		TEST_TRUE( #{replace}(&a, e) );
		TEST_TRUE( #{contains}(&a, e) );
	~

	test :replaceNone, %~
		#{element.set}(e, -1);
		TEST_FALSE( #{contains}(&a, e) );
		TEST_FALSE( #{replace}(&a, e) );
		TEST_FALSE( #{contains}(&a, e) );
	~

	test :remove, %~
		#{element.set}(e, 1);
		TEST_TRUE( #{contains}(&a, e) );
		TEST_TRUE( #{remove}(&a, e) );
		TEST_FALSE( #{contains}(&a, e) );
	~

	test :removeNone, %~
		#{element.set}(e, -1);
		TEST_FALSE( #{contains}(&a, e) );
		TEST_FALSE( #{remove}(&a, e) );
	~

	test :iterate, %~
		#{it} it;
		size_t i = 0;
		#{itCtor}(&it, &a);
		while(#{itMove}(&it)) {
			#{element.type} e2 = #{itGet}(&it);
			#{element.dtor(:e2)};
			i++;
		}
		TEST_EQUAL( #{size}(&a), i );
	~

setup %~
	/* a: [1,2,3] */
	#{type} a, b;
	#{ctor}(&a);
	PUT(&a, 1); PUT(&a, 2); PUT(&a, 3);
~
cleanup %~
	#{dtor}(&a);
	#{dtor}(&b);
~

	test :copy, %~
		#{copy}(&b, &a);
		TEST_TRUE( #{equal}(&a, &b) );
	~

	test :empty, %~
		#{ctor}(&b);
		TEST_FALSE( #{empty}(&a) );
		TEST_TRUE( #{empty}(&b) );
	~

setup %~
	/* a: [1,2,3], b: [2,3,4] */
	#{type} a, b, c;
	#{ctor}(&a);
	#{ctor}(&b);
	#{ctor}(&c);
	PUT(&a, 1); PUT(&a, 2); PUT(&a, 3);
	PUT(&b, 4); PUT(&b, 2); PUT(&b, 3);
~
cleanup %~
	#{dtor}(&a);
	#{dtor}(&b);
	#{dtor}(&c);
~

	test :exclude, %~
		PUT(&c, 1);
		#{exclude}(&a, &b);
		TEST_TRUE( #{equal}(&a, &c) );
	~

	test :include, %~
		PUT(&c, 1); PUT(&c, 2); PUT(&c, 3); PUT(&c, 4);
		#{include}(&a, &b);
		TEST_TRUE( #{equal}(&a, &c) );
	~

	test :invert, %~
		PUT(&c, 1); PUT(&c, 4);
		#{invert}(&a, &b);
		TEST_TRUE( #{equal}(&a, &c) );
	~

	test :retain, %~
		PUT(&c, 2); PUT(&c, 3);
		#{retain}(&a, &b);
		TEST_TRUE( #{equal}(&a, &c) );
	~

end