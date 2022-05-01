# frozen_string_literal: true


require 'autoc/container'


module AutoC


  class Set < Container

    def orderable? = false # No idea how to compute the ordering of this container

    private def configure
      super
      def_method :int, :put, { self: type, value: element.const_type } do
        header %{
          @brief Put a value

          @param[in] self set to put into
          @param[in] value value to put
          @return non-zero value on successful put and zero value and zero value otherwise
          
          This function puts a *copy* of the specified `value` to the set only if there is no equavalent element in the set.
          The returned value indicates whether a new value in put or the set already contains an equivalent element.

          After call to this function the set will contain an element equivalent to the `value` which is either the already contained element or a copy of the specified `value`.
          
          The function requires the element's type to be both *comparable* and *copyable*.

          @since 2.0
        }
      end
      def_method :int, :push, { self: type, value: element.const_type } do
        header %{
          @brief Force put a value

          @param[in] self set to put into
          @param[in] value value to put
          @return non-zero value on successful replacement and zero value and zero value otherwise

          This function puts a *copy* of the specified `value` to the set replacing already contained element if the is one.
          The return value indicates whether this is a replacement of an already contained element or a put of a new element.

          After call to this function the set will contain an element equivalent to the `value`.

          The function requires the element's type to be both *comparable* and *copyable*.

          @since 2.0
        }
      end
      def_method :int, :remove, { self: type, value: element.const_type } do
        header %{
          @brief Remove value from the set
          TODO
        }
      end
      def_method :int, :disjoint, { self: const_type, other: const_type }, refs: 2, require:-> { !@omit_set_operations } do
        code %{
          #{range.type} r;
          assert(self);
          assert(other);
          for(r = #{range.new}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            if(#{contains}(other, *#{range.view_front}(&r))) return 0;
          }
          for(r = #{range.new}(other); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            if(#{contains}(self, *#{range.view_front}(&r))) return 0;
          }
          return 1;
        }
        header %{
          @brief Check two sets for common elements

          @param[in] self set to check
          @param[in] other set to check
          @return non-zero value if sets share no common elements and zero value otherwise

          This function returns non-zero value if the specified sets are disjoint (mutually exclusive) that is they share no common elements and zero value otherwise.

          @since 2.0
        }
      end
      def_method :int, :subset, { self: const_type, other: const_type }, refs: 2, require:-> { !@omit_set_operations } do
        code %{
          #{range.type} r;
          assert(self);
          assert(other);
          for(r = #{range.new}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            if(!#{contains}(other, *#{range.view_front}(&r))) return 0;
          }
          return 1;
        }
        header %{
          @brief Return non-zero value if the set is a subset of the specified set
          TODO
        }
      end
      def_method :void, :join, { self: type, other: const_type }, refs: 2, require:-> { !@omit_set_operations } do
        code %{
          #{range.type} r;
          assert(self);
          assert(other);
          for(r = #{range.new}(other); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{put}(self, *#{range.view_front}(&r));
          }
        }
        header %{
          @brief Append contents of the specified set (set OR operation)
          TODO
        }
      end
      def_method :void, :subtract, { self: type, other: const_type }, refs: 2, require:-> { !@omit_set_operations } do
        code %{
          #{range.type} r;
          assert(self);
          assert(other);
          for(r = #{range.new}(other); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{remove}(self, *#{range.view_front}(&r));
          }
        }
        header %{
          @brief Exclude contents of the specified set (set SUBTRACT operation)
          TODO
        }
      end
      def_method :void, :intersect, { self: type, other: const_type }, refs: 2, require:-> { !@omit_set_operations } do
        code %{
          #{type} t;
          assert(self);
          assert(other);
          #{copy}(&t, self);
          #{subtract}(&t, other);
          #{subtract}(self, &t);
          #{destroy}(&t);
        }
        header %{
          @brief Retain elements shared by both specified sets (set AND operation)
          TODO
        }
      end
      def_method :void, :disjoin, { self: type, other: const_type }, refs: 2, require:-> { !@omit_set_operations } do
        code %{
          #{type} t;
          assert(self);
          assert(other);
          #{copy}(&t, self);
          #{intersect}(&t, other);
          #{join}(self, other);
          #{subtract}(self, &t);
          #{destroy}(&t);
        }
        header %{
          @brief Make the set to contain the elements not shared by both specified sets (set XOR operation)
          TODO
        }
      end
    end
  end


end