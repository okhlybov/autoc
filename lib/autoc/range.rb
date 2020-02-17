require 'autoc/type'


module AutoC


  class Range < Composite

    def initialize(container, prefix, deps)
      @container = Type.coerce(container)
      super(nil, prefix, deps << @container)
    end

    def type
      @type ||= "#{@container.type}Range"
    end

    def_redirector :create, 1

    def interface(stream)
      stream << %$
        #{declare} #{type}* #{create}(#{type}* self, const #{@container.type}* iterable);
      $
    end

  end # Range


  class Range::Input < Range

    %i(empty popFront front frontView).each {|s| def_redirector s, 1}

    def interface(stream)
      super
      stream << %$
        #{declare} int #{empty}(const #{type}* self);
        #{declare} void #{popFront}(#{type}* self);
        #{declare} #{@container.element.type} #{front}(const #{type}* self);
        #{declare} const #{@container.element.type}* #{frontView}(const #{type}* self);
      $
    end

  end # Input


  class Range::Forward < Range::Input

    def_redirector :save, 2

    def interface(stream)
      super
      stream << %$
        #{declare} #{type}* #{save}(#{type}* self, const #{type}* origin);
      $
    end
  end # Forward


  class Range::Bidirectional < Range::Forward

    %i(popBack back backView).each {|s| def_redirector s, 1}

    def interface(stream)
      super
      stream << %$
        #{declare} void #{popBack}(#{type}* self);
        #{declare} #{@container.element.type} #{back}(const #{type}* self);
        #{declare} const #{@container.element.type}* #{backView}(const #{type}* self);
      $
    end

  end # Bidirectional


  class Range::RandomAccess < Range::Bidirectional

    %i(size get view).each {|s| def_redirector s, 1}

    def interface(stream)
      super
      stream << %$
        #{declare} size_t #{size}(const #{type}* self);
        #{declare} #{@container.element.type} #{get}(const #{type}* self, size_t index);
        #{declare} const #{@container.element.type}* #{view}(const #{type}* self, size_t index);
      $
    end

  end # RandomAccess


end # AutoC