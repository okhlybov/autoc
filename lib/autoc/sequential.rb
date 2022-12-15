# frozen_string_literal: true


module AutoC


  # Method implementations for types which maintain predictable element order (vector, list, queue etc.)
  module Sequential

  private

    def configure
      super
      contains.configure do
        dependencies << find_first
        inline_code %{
          return #{find_first.(*parameters)} != NULL;
        }
      end
      find_first.configure do
        code %{
          #{range} r;
          assert(target);
          for(r = #{range.new.(target)}; !#{range.empty.(:r)}; #{range.pop_front.(:r)}) {
            #{element.const_lvalue} e = #{range.view_front.(:r)};
            if(#{element.equal.('*e', value)}) return e;
          }
          return NULL;
        }
      end
      equal.configure do
        code %{
          assert(left);
          assert(right);
          if(#{size.(left)} == #{size.(right)}) {
            #{range} rl, rr;
            for(
              rl = #{range.new.(left)}, rr = #{range.new.(right)};
              !#{range.empty.(:rl)} && !#{range.empty.(:rr)};
              #{range.pop_front.(:rl)}, #{range.pop_front.(:rr)}
            ) {
              #{element.const_lvalue} le = #{range.view_front.(:rl)};
              #{element.const_lvalue} re = #{range.view_front.(:rr)};
              if(#{element.equal.('*le', '*re')}) return 1;
            }
          }
          return 0;
        }
      end
      compare.configure do
        code %{
          size_t remaining, ls, rs;
          #{range} rl, rr;
          assert(left);
          assert(right);
          ls = #{size.(left)}; 
          rs = #{size.(right)};
          /* comparing common parts */
          for(
            rl = #{range.new.(left)}, rr = #{range.new.(right)}, remaining = ls < rs ? ls : rs; /* min(ls, rs) */
            remaining > 0;
            #{range.pop_front.(:rl)}, #{range.pop_front.(:rr)}, --remaining
          ) {
            #{element.const_lvalue} le = #{range.view_front.(:rl)};
            #{element.const_lvalue} re = #{range.view_front.(:rr)};
            int c = #{element.compare.('*le', '*re')};
            if(c != 0) {
              return c; /* early exit on first non-equal pair encountered */
            }
          }
          if(ls == rs) {
            return 0; /* both vectors are completely equal */
          } else {
            return ls > rs ? +1 : -1; /* the longer sequence of the two with equal common part is considered "the more" */
          }
        }
      end
      hash_code.configure do
        code %{
          #{range} r;
          size_t result;
          #{hasher.to_s} hash;
          for(r = #{range.new.(target)}; !#{range.empty.(:r)}; #{range.pop_front.(:r)}) {
            #{element.const_lvalue} e = #{range.view_front.(:r)};
            #{hasher.update(:hash, element.hash_code.('*e'))};
          }
          result = #{hasher.result(:hash)};
          #{hasher.destroy(:hash)};
          return result;
        }
      end
    end

  end # Sequential


end