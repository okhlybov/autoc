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

    redirect :create, 1

    def interface(stream)
      stream << %$
        #{declare} #{type}* #{create}(#{type}* self, const #{@container.type}* iterable);
      $
    end

    def input?
      is_a?(Input)
    end

    def forward?
      is_a?(Forward)
    end

    def bidirectional?
      is_a?(Bidirectional)
    end

    def random_access?
      is_a?(RandomAccess)
    end

  end # Range


  class Range::Input < Range

    %i(empty popFront front frontView).each {|s| redirect s, 1}

    def interface(stream)
      super
      stream << %$
        #{declare} int #{empty}(const #{type}* self);
        #{declare} void #{popFront}(#{type}* self);
        #{declare} const #{@container.element.type}* #{frontView}(const #{type}* self);
      $
      stream << "#{declare} #{@container.element.type} #{front}(const #{type}* self);" if @container.element.copyable?
    end

  end # Input


  class Range::Forward < Range::Input

    redirect :save, 2

    def interface(stream)
      super
      stream << %$
        #{declare} #{type}* #{save}(#{type}* self, const #{type}* origin);
      $
    end
  end # Forward


  class Range::Bidirectional < Range::Forward

    %i(popBack back backView).each {|s| redirect s, 1}

    def interface(stream)
      super
      stream << %$
        #{declare} void #{popBack}(#{type}* self);
        #{declare} const #{@container.element.type}* #{backView}(const #{type}* self);
      $
      stream << "#{declare} #{@container.element.type} #{back}(const #{type}* self);" if @container.element.copyable?
    end

  end # Bidirectional


  class Range::RandomAccess < Range::Bidirectional

    %i(size get view).each {|s| redirect s, 1}

    def interface(stream)
      super
      stream << %$
        #{declare} size_t #{size}(const #{type}* self);
        #{declare} const #{@container.element.type}* #{view}(const #{type}* self, size_t index);
      $
      stream << "#{declare} #{@container.element.type} #{get}(const #{type}* self, size_t index);" if @container.element.copyable?
    end

  end # RandomAccess


end # AutoC