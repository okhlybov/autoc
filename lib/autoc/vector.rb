require 'autoc/type'


module AutoC


  class Vector < Container

    def initialize(type, element, prefix: nil, deps: [])
      super(type, element, prefix, deps)
    end

    def interface(stream)
      stream << %$
        typedef struct {
          #{element.type}* elements;
          size_t element_count;
        } #{type};
      $
    end

  end # Vector


end # AutoC