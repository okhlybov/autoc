# frozen_string_literal: true


require 'autoc/container'


module AutoC


  class Map < AssociativeContainer

    private def configure
      super
      def_method :void, :purge, { self: type } do
        header %{
          @brief Remove and destroy all contained keys along with associated elements
          TODO
        }
      end
      def_method element.const_ptr_type, :view, { self: const_type, key: key.const_type } do
        header %{
          @brief Return a view of the element associated with the specified key or NULL if there is no such element
          TODO
        }
      end
      def_method :int, :put, { self: type, key: key.const_type, value: element.const_type } do
        header %{
          @brief Associate a copy of the specified element with a copy of the specified key if there is no such key present
          TODO
        }
      end
      def_method :int, :set, { self: type, key: key.const_type, value: element.const_type } do
        header %{
          @brief Associate a copy of the specified element with a copy of the specified key overriding existing key/value pair
          TODO
        }
      end
      def_method :int, :remove, { self: type, key: key.const_type } do
        header %{
          @brief Remove and destroy key and element pair referenced by the specified key if it exists
          TODO
        }
      end
      def_method element.type, :get, { self: const_type, key: key.const_type } do
        inline_code %{
          #{element.type} result;
          #{element.const_ptr_type} e = #{view}(self, key);
          #{element.copy(:result, '*e')};
          return result;
        }
        header %{
          @brief Return a copy of the element associated with the specified key
          TODO
        }
      end
    end

  end


end