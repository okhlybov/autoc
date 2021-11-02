# frozen_string_literal: true


require 'autoc/container'


module AutoC


  class Map < AssociativeContainer

    def initialize(*args)
      super
      @purge = function(self, :purge, 1, { self: type }, :void)
      @view = function(self, :view, 1, { self: type, key: key.const_type }, element.const_ptr_type)
      @get = function(self, :get, 1, { self: type, key: key.const_type }, element.type)
      @put = function(self, :put, 1, { self: type, key: key.const_type, value: element.const_type }, :int)
      @force = function(self, :force, 1, { self: type, key: key.const_type, value: element.const_type }, :int)
      @remove = function(self, :remove, 1, { self: type, key: key.const_type }, :int)
    end

    def composite_interface_definitions(stream)
      super
      stream << %$
        /**
        * @brief Remove and destroy all contained keys along with associated elements
        */
        #{declare(@purge)};
        /**
         * @brief Associate a copy of the specified element with a copy of the specified key if there is no such key present
         */
        #{declare(@put)};
        /**
         * @brief Associate a copy of the specified element with a copy of the specified key overriding existing key/value pair
         */
        #{declare(@force)};
        /**
         * @brief Remove and destroy key and element pair referenced by the specified key if it exists
         */
        #{declare(@remove)};
        /**
        * @brief Return a view of the element associated with the specified key or NULL if there is no such element
        */
        #{declare(@view)};
        /**
        * @brief Return a copy of the element associated with the specified key
        */
        #{define(@get)} {
          #{element.type} result;
          #{element.const_ptr_type} e = #{view}(self, key);
          #{element.copy(:result, '*e')};
          return result;
        }
      $
    end
  end


end