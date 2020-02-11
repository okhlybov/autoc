require 'autoc/type'


module AutoC


  class Range < Composite

    def initialize(container, prefix, deps)
      @container = Type.coerce(container)
      super("#{@container.type}Range", prefix, deps << @container)
    end

    def_redirector :create, 2

    def interface(stream)
      stream << %$
        #{declare} #{type}* #{create}(#{type}* self, #{@container.type}* iterable);
      $
    end

  end # Range


  class Range::Input < Range

    %i(empty popFront front).each {|s| def_redirector s, 1}

    def initialize(*args)
      super
      raise TraitError, 'container element must be copyable' unless @container.element.copyable?
    end

    def interface(stream)
      super
      stream << %$
        #{declare} int #{empty}(#{type}* self);
        #{declare} void #{popFront}(#{type}* self);
        #{declare} #{@container.element.type} #{front}(#{type}* self);
      $
    end

  end # Input


  class Range::Forward < Range::Input

    def_redirector :save, 2

    def interface(stream)
      super
      stream << %$
        #{declare} #{type}* #{save}(#{type}* self, #{type}* origin);
      $
    end
  end # Forward


  class Range::Bidirectional < Range::Forward

    %i(popBack back).each {|s| def_redirector s, 1}

    def interface(stream)
      super
      stream << %$
        #{declare} void #{popBack}(#{type}* self);
        #{declare} #{@container.element.type} #{back}(#{type}* self);
      $
    end

  end # Bidirectional


  class Range::RandomAccess < Range::Bidirectional

    %i(size get).each {|s| def_redirector s, 1}

    def interface(stream)
      super
      stream << %$
        #{declare} size_t #{size}(#{type}* self);
        #{declare} #{@container.element.type} #{get}(#{type}* self, size_t index);
      $
    end

  end # RandomAccess


end # AutoC