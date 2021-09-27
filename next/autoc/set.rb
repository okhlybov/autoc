# frozen_string_literal: true


require 'autoc/container'


module AutoC


  class Set < Container

    def initialize(*args)
      super
      @put = function(self, :put, 1, { self: type, value: element.const_type }, :int)
    end

    def composite_interface_definitions(stream)
      super
      stream << %$
        /**
         * @brief Put a copy of the value into the set
         */
        #{declare(@put)};
      $
    end

  end


end