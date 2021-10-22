# frozen_string_literal: true


require 'autoc/container'


module AutoC


  class Map < AssociativeContainer

    def initialize(*args)
      super
      @purge = function(self, :purge, 1, { self: type }, :void)
      @view = function(self, 1, { self: type, key: key.const_type }, element.const_ptr_type)
      @get = function(self, 1, { self: type, key: key.const_type }, element.type)
      @put = function(self, :put, 1, { self: type, key: key.const_type, value: element.const_type }, :int)
      @remove = function(self, :remove, 1, { self: type, key: key.const_type }, :int)
    end

    def composite_interface_definitions(stream)
      super
      stream << %$
        /**
        * @brief Remove and destroy all contained keys along with associated elements
        */
        #{declare(@purge)};
        #{declare(@view)}; // TODO
        #{declare(@get)}; // TODO
        /**
         * @brief Put a copy of the value into the map
         */
        #{declare(@put)};
        /**
         * @brief Remove value from the set
         */
        #{declare(@remove)};
      $
    end

    def composite_interface_declarations(stream)
      super
      stream << %$
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