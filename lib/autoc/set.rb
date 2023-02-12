# frozen_string_literal: true


require 'autoc/collection'


module AutoC


  class Set < Collection

    def orderable? = false # No idea how to compute the ordering of this container

    def initialize(*args, set_operations: true, **kws)
      super(*args, **kws)
      @set_operations = set_operations # Instruct to emit standard set operations (conjunction, disjunction etc.)
    end

  private
    
    def configure
      super
      method(:int, :put, { target: rvalue, value: element.const_rvalue }, constraint:-> { element.copyable? && element.comparable? }).configure do
        header %{
          @brief Put a value

          @param[in] target set to put into
          @param[in] value value to put
          @return non-zero value on successful put and zero value and zero value otherwise
          
          This function puts a *copy* of the specified `value` to the set only if there is no equavalent element in the set.
          The returned value indicates whether a new value in put or the set already contains an equivalent element.

          After call to this function the set will contain an element equivalent to the `value` which is either the already contained element or a copy of the specified `value`.
          
          The function requires the element's type to be both *comparable* and *copyable*.

          @since 2.0
        }
      end
      method(:int, :push, { target: rvalue,  value: element.const_rvalue }, constraint:-> { element.copyable? && element.comparable? }).configure do
        header %{
          @brief Force put a value

          @param[in] target set to put into
          @param[in] value value to put
          @return non-zero value if a value was replaced or zero value if a new value was inserted

          This function puts a *copy* of the specified `value` to the set replacing already contained element if the is one.
          The return value indicates whether this is a replacement of an already contained element or a put of a new element.

          After call to this function the set will contain an element equivalent to the `value`.

          The function requires the element's type to be both *comparable* and *copyable*.

          @since 2.0
        }
      end
      method(:int, :remove, { target: rvalue, value: element.const_rvalue }, constraint:-> { element.comparable? }).configure do
        header %{
          @brief Remove value

          @param[in] target set to process
          @param[in] value value to remove
          @return non-zero value on successful removal and zero value otherwise

          This function removes and destroys (the first occurrence of) the element considered equal to the specified value.
          The function returns zero value if `target` contains no such element.

          @since 2.0
        }
      end
      method(:int, :subset, { target: const_rvalue, other: const_rvalue }, constraint:-> { element.comparable? }).configure do
        header %{
          @brief Check if one set is a subset of another

          @param[in] target set to compare
          @param[in] other set to compare
          @return non-zero value if `target` set is a subset of `other` set and zero value otherwise

          @since 2.0
        }
      end
      equal.configure do
        code %{
          assert(left);
          assert(right);
          return #{subset.(left, right)} && #{subset.(right, left)};
        }
      end
      method(:int, :disjoint, { left: const_rvalue, right: const_rvalue }, constraint:-> { @set_operations && element.comparable? }).configure do
        code %{
          #{range} r;
          #{element.const_lvalue} e;
          assert(left);
          assert(right);
          for(r = #{range.new.(left)}; !#{range.empty.(:r)}; #{range.pop_front.(:r)}) {
            e = #{range.view_front.(:r)};
            if(#{contains.(right, '*e')}) return 0;
          }
          for(r = #{range.new.(right)}; !#{range.empty.(:r)}; #{range.pop_front.(:r)}) {
            e = #{range.view_front.(:r)};
            if(#{contains.(left, '*e')}) return 0;
          }
          return 1;
        }
        header %{
          @brief Scan two sets for common elements

          @param[in] left set to check
          @param[in] right set to check
          @return non-zero value if sets share no common elements and zero value otherwise

          This function returns non-zero value if the specified sets are disjoint that is they share no common elements and zero value otherwise.

          @since 2.0
        }
      end
      method(:void, :join, { target: rvalue, source: const_rvalue }, constraint:-> { @set_operations && element.copyable? && element.comparable? }).configure do
        code %{
          #{range} r;
          #{element.const_lvalue} e;
          assert(target);
          assert(source);
          for(r = #{range.new.(source)}; !#{range.empty.(:r)}; #{range.pop_front.(:r)}) {
            e = #{range.view_front.(:r)};
            #{put.(target, '*e')};
          }
        }
        header %{
          @brief Join sets

          @param[in] target set to merge to
          @param[in] source set to get elements from

          This function copies all (new) elements from `source` set to `target` set.
          This is effectively a set join operation _target | source -> target_.

          @since 2.0
        }
      end
      method(:void, :create_join, { target: lvalue, left: const_rvalue, right: const_rvalue }, constraint:-> { @set_operations && default_constructible? && element.copyable? && element.comparable? }).configure do
        code %{
          #{range} r;
          #{element.const_lvalue} e;
          assert(target);
          assert(left);
          assert(right);
          #{default_create.(target)}; /* TODO create a set with specified capacity right away */
          for(r = #{range.new.(left)}; !#{range.empty.(:r)}; #{range.pop_front.(:r)}) {
            e = #{range.view_front.(:r)};
            #{put.(target, '*e')};
          }
          for(r = #{range.new.(right)}; !#{range.empty.(:r)}; #{range.pop_front.(:r)}) {
            e = #{range.view_front.(:r)};
            #{put.(target, '*e')};
          }
        }
        header %{
          @brief Join sets into new set

          @param[out] target set to merge set into
          @param[in] left set to merge
          @param[in] right set to merge

          This function creates a new `target` set which contains copies of elements from both source sets.
          This is effectively a set join operation _left | right -> target_.

          @since 2.0
        }
      end
      method(:void, :subtract, { target: rvalue, source: const_rvalue }, constraint:-> { @set_operations && element.copyable? && element.comparable? }).configure do
        code %{
          #{range} r;
          #{element.const_lvalue} e;
          assert(target);
          assert(source);
          for(r = #{range.new.(source)}; !#{range.empty.(:r)}; #{range.pop_front.(:r)}) {
            e = #{range.view_front.(:r)};
            #{remove.(target, '*e')};
          }
        }
        header %{
          @brief Set substraction

          @param[in] target set to subtract from
          @param[in] source set to get elements for subtraction

          This function removes all elements from `target` set which are contained in `source` set.
          This is effectively a set subtraction operation _target \\ source -> target_.

          @since 2.0
        }
      end
      method(:void, :create_difference, { target: lvalue, left: const_rvalue, right: const_rvalue }, constraint:-> { @set_operations && default_constructible? && element.copyable? && element.comparable? }).configure do
        code %{
          #{range} r;
          #{element.const_lvalue} e;
          assert(target);
          assert(left);
          assert(right);
          #{default_create.(target)};
          for(r = #{range.new.(left)}; !#{range.empty.(:r)}; #{range.pop_front.(:r)}) {
            e = #{range.view_front.(:r)};
            if(!#{contains.(right, '*e')}) #{put.(target, '*e')};
          }
        }
        header %{
          @brief Perform sets substraction into new set

          @param[out] target set to contain difference
          @param[in] left set to subtract from
          @param[in] right set to subtract

          This function creates new set and populates it with the copies of values from `left` set not contained in `right` set.
          This is effectively a set subtraction operation _left \\ right -> target_.

          @since 2.0
        }
      end
      method(:void, :intersect, { target: rvalue, source: const_rvalue }, constraint:-> { @set_operations && element.copyable? && element.comparable? }).configure do
        code %{
          #{type} t;
          assert(target);
          assert(source);
          #{copy.(:t, target)};
          #{subtract.(:t, source)};
          #{subtract.(target, :t)};
          #{destroy.(:t)};
        }
        header %{
          @brief Set intersection

          @param[in] target set to retain elements
          @param[in] source set to get elements for consideration

          This function retains elements in `target` set which are also contained in `source` set.
          This is effectively a set intersection operation _target & source -> target_.

          @since 2.0
        }
      end
      method(:void, :create_intersection, { target: lvalue, left: const_rvalue, right: const_rvalue }, constraint:-> { @set_operations && default_constructible? && element.copyable? && element.comparable? }).configure do
        code %{
          #{range} r;
          #{element.const_lvalue} e;
          assert(target);
          assert(left);
          assert(right);
          #{default_create.(target)};
          for(r = #{range.new.(left)}; !#{range.empty.(:r)}; #{range.pop_front.(:r)}) {
            e = #{range.view_front.(:r)};
            if(#{contains.(right, '*e')}) #{put.(target, '*e')};
          }
          for(r = #{range.new.(right)}; !#{range.empty.(:r)}; #{range.pop_front.(:r)}) {
            e = #{range.view_front.(:r)};
            if(#{contains.(left, '*e')}) #{put.(target, '*e')};
          }
        }
        header %{
          @brief Perform sets intersection into new set

          @param[out] target set to contain intersection
          @param[in] left set to get elements from
          @param[in] right set to get elements from

          This function creates a new set which contains copies of the elements shared by both source sets.
          This is effectively a set intersection operation left & right -> target_.

          @since 2.0
        }
      end
      method(:void, :disjoin, { target: rvalue, source: const_rvalue }, constraint:-> { @set_operations && element.copyable? && element.comparable? }).configure do
        code %{
          #{type} t;
          assert(target);
          assert(source);
          #{copy.(:t, target)};
          #{intersect.(:t, source)};
          #{join.(target, source)};
          #{subtract.(target, :t)};
          #{destroy.(:t)};
        }
        header %{
          @brief Set symmetric difference

          @param[in] target set to retain elements
          @param[in] source set to get elements for consideration

          This function collects elements in `target` which are contained in either `target` set or `source` set, but not in both.
          This is effectively a set symmetric difference operation _target ^ source -> target_.

          @since 2.0
        }
      end
      method(:void, :create_disjunction, { target: lvalue, left: const_rvalue, right: const_rvalue }, constraint:-> { @set_operations && default_constructible? && element.copyable? && element.comparable? }).configure do
        code %{
          #{range} r;
          #{element.const_lvalue} e;
          assert(target);
          assert(left);
          assert(right);
          #{default_create.(target)};
          for(r = #{range.new.(left)}; !#{range.empty.(:r)}; #{range.pop_front.(:r)}) {
            e = #{range.view_front.(:r)};
            if(!#{contains.(right, '*e')}) #{put.(target, '*e')};
          }
          for(r = #{range.new.(right)}; !#{range.empty.(:r)}; #{range.pop_front.(:r)}) {
            e = #{range.view_front.(:r)};
            if(!#{contains.(left, '*e')}) #{put.(target, '*e')};
          }
        }
        header %{
          @brief Perform symmetric sets difference into new set

          @param[out] target set to contain difference
          @param[in] left set to get elements from
          @param[in] right set to get elements from

          This function creates a new set which contains copies of elements which are contained in either `target` set or `source` set, but not in both.
          This is effectively a set symmetric difference operation left ^ right -> target_.

          @since 2.0
        }
      end
    end

  end # Set


end