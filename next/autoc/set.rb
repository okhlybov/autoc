# frozen_string_literal: true


require 'autoc/container'


module AutoC


  class Set < Container

    def initialize(*args)
      super
      # Declare common set functions
      @put = function(self, :put, 1, { self: type, value: element.const_type }, :int)
      @purge = function(self, :purge, 1, { self: type }, :void)
      @remove = function(self, :remove, 1, { self: type, value: element.const_type }, :int)
    end

    def composite_interface_definitions(stream)
      super
      stream << %$
        /**
         * @brief Put a copy of the value into the set
         */
        #{declare(@put)};
        /**
         * @brief Remove and destroy all contained elements
         */
        #{declare(@purge)};
        /**
         * @brief Remove value from the set
         */
        #{declare(@remove)};
      $
    end
  end


  module Set::Operations

    def initialize(*args)
      super
      @disjoint = function(self, :disjoint, 2, { self: const_type, other: const_type }, :int)
      @subset = function(self, :subset, 2, { self: const_type, other: const_type }, :int)
      @join = function(self, :join, 2, { self: type, other: const_type }, :void)
      @subtract = function(self, :subtract, 2, { self: type, other: const_type }, :void)
      @intersect = function(self, :intersect, 2, { self: type, other: const_type }, :void)
      @disjoin = function(self, :disjoin, 2, { self: type, other: const_type }, :void)
    end

    def composite_interface_definitions(stream)
      super
      stream << %$
        /**
         * @brief Return non-zero value if both specified sets share no common elements
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
      $
    end

    def definitions(stream)
      super
      stream << %$
        #{define(@subset)} {
          assert(self);
          assert(other);
          for(#{range.type} r = #{get_range}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            if(!#{contains}(other, *#{range.front_view}(&r))) return 0;
          }
          return 1;
        }
        #{define(@disjoint)} {
          assert(self);
          assert(other);
          for(#{range.type} r = #{get_range}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            if(#{contains}(other, *#{range.front_view}(&r))) return 0;
          }
          for(#{range.type} r = #{get_range}(other); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            if(#{contains}(self, *#{range.front_view}(&r))) return 0;
          }
          return 1;
        }
        #{define(@join)} {
          assert(self);
          assert(other);
          for(#{range.type} r = #{get_range}(other); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{put}(self, *#{range.front_view}(&r));
          }
        }
        #{define(@subtract)} {
          assert(self);
          assert(other);
          for(#{range.type} r = #{get_range}(other); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{remove}(self, *#{range.front_view}(&r));
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
      $
    end
  end
end