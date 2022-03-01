# frozen_string_literal: true


require 'autoc/container'


module AutoC


  class Set < Container

    def initialize(*args)
      super
      # Declare common set functions
      @put = function(self, :put, 1, { self: type, value: element.const_type }, :int)
      @push = function(self, :push, 1, { self: type, value: element.const_type }, :int)
      @look = function(self, :look, 1, { self: type, value: element.const_type }, element.const_ptr_type)
      @purge = function(self, :purge, 1, { self: type }, :void)
      @remove = function(self, :remove, 1, { self: type, value: element.const_type }, :int)
      unless @omit_set_operations
        @disjoint = function(self, :disjoint, 2, { self: const_type, other: const_type }, :int)
        @subset = function(self, :subset, 2, { self: const_type, other: const_type }, :int)
        @join = function(self, :join, 2, { self: type, other: const_type }, :void)
        @subtract = function(self, :subtract, 2, { self: type, other: const_type }, :void)
        @intersect = function(self, :intersect, 2, { self: type, other: const_type }, :void)
        @disjoin = function(self, :disjoin, 2, { self: type, other: const_type }, :void)
        end
    end

    def composite_interface_definitions(stream)
      super
      stream << %$
        /**
          #{ingroup}
          @brief Put a value

          @param[in] self set to put into
          @param[in] value value to put
          @return non-zero value on successful put and zero value and zero value otherwise
          
          This function puts a *copy* of the specified `value` to the set only if there is no equavalent element in the set.
          The returned value indicates whether a new value in put or the set already contains an equivalent element.

          After call to this function the set will contain an element equivalent to the `value` which is either the already contained element or a copy of the specified `value`.
          
          The function requires the element's type to be both *comparable* and *copyable*.

          @since 2.0
        */
        #{declare(@put)};
        /**
          #{ingroup}
          @brief Force put a value

          @param[in] self set to put into
          @param[in] value value to put
          @return non-zero value on successful replacement and zero value and zero value otherwise

          This function puts a *copy* of the specified `value` to the set replacing already contained element if the is one.
          The return value indicates whether this is a replacement of an already contained element or a put of a new element.

          After call to this function the set will contain an element equivalent to the `value`.

          The function requires the element's type to be both *comparable* and *copyable*.

          @since 2.0
        */
        #{declare(@push)};
        /**
          #{ingroup}
          @brief Remove and destroy all contained elements

          @param[in] self list to be purged

          The elements are destroyed with respective destructor.

          After call to this function the set will remain intact yet contain zero elements.

          @since 2.0
        */
        #{declare(@purge)};
        /**
          #{ingroup}
          @brief Get a view of contained element

          @param[in] self set to put into
          @param[in] value value to put
          @return a view of an element equivalent to the `value`

          This function is used to get a constant reference (in form of the C pointer) to an element contained in `self` equavalent to the specified `value`.

          @note Equivalent element must exist (see @ref #{contains}).

          @since 2.0
         */
        #{declare(@look)};
        /**
         * @brief Remove value from the set
         */
        #{declare(@remove)};
      $
      stream << %$
        /**
          #{ingroup}
          @brief Check two sets for common elements

          @param[in] self set to check
          @param[in] other set to check
          @return non-zero value if sets share no common elements and zero value otherwise

          This function returns non-zero value if the specified sets are disjoint (mutually exclusive) that is they share no common elements and zero value otherwise.

          @since 2.0
        */
        #{declare(@disjoint)};
        /**
        * @brief Return non-zero value if the set is a subset of the specified set
        */
        #{declare(@subset)};
        /**
        * @brief Append contents of the specified set (set OR operation)
        */
        #{declare(@join)};
        /**
        * @brief Exclude contents of the specified set (set SUBTRACT operation)
        */
        #{declare(@subtract)};
        /**
        * @brief Retain elements shared by both specified sets (set AND operation)
        */
        #{declare(@intersect)};
        /**
        * @brief Make the set to contain the elements not shared by both specified sets (set XOR operation)
        */
        #{declare(@disjoin)};
      $ unless @omit_set_operations
    end

    def definitions(stream)
      super
      stream << %$
        #{define(@subset)} {
          #{range.type} r;
          assert(self);
          assert(other);
          for(r = #{get_range}(self); !#{range.empty}(&r); #{range.pop}(&r)) {
            if(!#{contains}(other, *#{range.view}(&r))) return 0;
          }
          return 1;
        }
        #{define(@disjoint)} {
          #{range.type} r;
          assert(self);
          assert(other);
          for(r = #{get_range}(self); !#{range.empty}(&r); #{range.pop}(&r)) {
            if(#{contains}(other, *#{range.view}(&r))) return 0;
          }
          for(r = #{get_range}(other); !#{range.empty}(&r); #{range.pop}(&r)) {
            if(#{contains}(self, *#{range.view}(&r))) return 0;
          }
          return 1;
        }
        #{define(@join)} {
          #{range.type} r;
          assert(self);
          assert(other);
          for(r = #{get_range}(other); !#{range.empty}(&r); #{range.pop}(&r)) {
            #{put}(self, *#{range.view}(&r));
          }
        }
        #{define(@subtract)} {
          #{range.type} r;
          assert(self);
          assert(other);
          for(r = #{get_range}(other); !#{range.empty}(&r); #{range.pop}(&r)) {
            #{remove}(self, *#{range.view}(&r));
          }
        }
        /* FIXME avoid creating temporary copy(s) of the sets */
        #{define(@intersect)} {
          #{type} t;
          assert(self);
          assert(other);
          #{copy}(&t, self);
          #{subtract}(&t, other);
          #{subtract}(self, &t);
          #{destroy}(&t);
        }
        #{define(@disjoin)} {
          #{type} t;
          assert(self);
          assert(other);
          #{copy}(&t, self);
          #{intersect}(&t, other);
          #{join}(self, other);
          #{subtract}(self, &t);
          #{destroy}(&t);
        }
      $ unless @omit_set_operations
    end
  end


end