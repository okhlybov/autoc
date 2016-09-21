module AutoC


# :nodoc
module Sets

  def write_intf_types(stream)
  	super
    stream << %$
      /***
      **** #{type}<#{element.type}>
      ***/
    $ if public?
  end

	def write_intf_decls(stream, declare, define)
	    super
		stream << %$
			#{declare} #{ctor.declaration};
			#{declare} #{dtor.declaration};
			#{declare} #{copy.declaration};
			#{declare} #{equal.declaration};
			#{declare} #{identify.declaration};
			#{declare} void #{purge}(#{type_ref});
			#{declare} int #{contains}(#{type_ref}, #{element.type});
			#{declare} #{element.type} #{get}(#{type_ref}, #{element.type});
			#{declare} size_t #{size}(#{type_ref});
			#define #{empty}(self) (#{size}(self) == 0)
			#{declare} int #{put}(#{type_ref}, #{element.type});
			#{declare} int #{replace}(#{type_ref}, #{element.type});
			#{declare} int #{remove}(#{type_ref}, #{element.type});
			#{declare} void #{exclude}(#{type_ref}, #{type_ref});
			#{declare} void #{retain}(#{type_ref}, #{type_ref});
			#{declare} void #{include}(#{type_ref}, #{type_ref});
			#{declare} void #{invert}(#{type_ref}, #{type_ref});
		$
	end

	def write_impls(stream, define)
		super
		stream << %$
			static #{element.type_ref} #{itGetRef}(#{it_ref});
			static int #{containsAllOf}(#{type_ref} self, #{type_ref} other) {
				#{it} it;
				#{itCtor}(&it, self);
				while(#{itMove}(&it)) {
				  if(!#{contains}(other, *#{itGetRef}(&it))) return 0;
				}
				return 1;
			}
	      #{define} #{copy.definition} {
	        #{it} it;
	        #{assert}(src);
	        #{assert}(dst);
	        #{ctor}(dst);
	        #{itCtor}(&it, src);
	        while(#{itMove}(&it)) #{put}(dst, *#{itGetRef}(&it));
	      }
	      #{define} #{equal.definition} {
	        #{assert}(lt);
	        #{assert}(rt);
	        return #{size}(lt) == #{size}(rt) && #{containsAllOf}(lt, rt) && #{containsAllOf}(rt, lt);
	      }
	      #{define} #{identify.definition} {
	        #{it} it;
	        size_t result = 0;
	        #{assert}(self);
	        #{itCtor}(&it, self);
	        while(#{itMove}(&it)) {
	          #{element.type}* e = #{itGetRef}(&it);
	          result ^= #{element.identify("*e")};
	          result = AUTOC_RCYCLE(result);
	        }
	        return result;
	      }
	      #{define} size_t #{size}(#{type_ref} self) {
	        #{assert}(self);
	        return self->size;
	      }
	      #{define} void #{include}(#{type_ref} self, #{type_ref} other) {
	        #{it} it;
	        #{assert}(self);
	        #{assert}(other);
	        #{itCtor}(&it, other);
	        while(#{itMove}(&it)) #{put}(self, *#{itGetRef}(&it));
	      }
	      #{define} void #{retain}(#{type_ref} self, #{type_ref} other) {
	        #{it} it;
	        #{type} set;
	        #{assert}(self);
	        #{assert}(other);
	        #{ctor}(&set);
	        #{itCtor}(&it, self);
	        while(#{itMove}(&it)) {
	          #{element.type}* e = #{itGetRef}(&it);
	          #{assert}(e);
	          if(#{contains}(other, *e)) #{put}(&set, *e);
	        }
	        #{dtor}(self);
	        *self = set;
	      }
	      #{define} void #{invert}(#{type_ref} self, #{type_ref} other) {
	        #{it} it;
	        #{type} set;
	        #{assert}(self);
	        #{assert}(other);
	        #{ctor}(&set);
	        #{itCtor}(&it, self);
	        while(#{itMove}(&it)) {
	          #{element.type}* e = #{itGetRef}(&it);
	          if(!#{contains}(other, *e)) #{put}(&set, *e);
	        }
	        #{itCtor}(&it, other);
	        while(#{itMove}(&it)) {
	          #{element.type}* e = #{itGetRef}(&it);
	          if(!#{contains}(self, *e)) #{put}(&set, *e);
	        }
	        #{dtor}(self);
	        *self = set;
	      }
	      #{define} void #{exclude}(#{type_ref} self, #{type_ref} other) {
	        #{it} it;
	        #{assert}(self);
	        #{assert}(other);
	        #{itCtor}(&it, other);
	        while(#{itMove}(&it)) #{remove}(self, *#{itGetRef}(&it));
	      }
		$
	end

end # Sets


end # AutoC