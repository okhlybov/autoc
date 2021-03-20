require 'autoc/type'


module AutoC


  # @abstract
  class Range < Composite

    # Range's methods are assumed to be lightweight therefore are declared inline by default

    def declare; :static end
    def define; :AUTOC_INLINE end

    def initialize(container, prefix, deps)
      super(nil, prefix, deps << (@container = Type.coerce(container)))
    end

    def type; "#{@container.type}Range" end # Lazy container type query as it may be unset by the time the Range's type is computed

    redirect :create, 1

    def interface_definitions(stream)
      super
      stream << %$
        #{declare} #{type}* #{create}(#{type}* self, const #{@container.type}* iterable);
      $
    end

  end # Range


  class Range::Input < Range

    %i(empty popFront front frontView).each {|s| redirect s, 1}

    def interface_definitions(stream)
      super
      stream << %$
        #{declare} int #{empty}(const #{type}* self);
        #{declare} void #{popFront}(#{type}* self);
        #{declare} const #{@container.element.type}* #{viewFront}(const #{type}* self);
      $
      stream << "#{declare} #{@container.element.type} #{front}(const #{type}* self);" if @container.element.cloneable?
    end

  end # Input


  class Range::Forward < Range::Input

    redirect :save, 2

    def interface_definitions(stream)
      super
      stream << %$
        #{declare} #{type}* #{save}(#{type}* self, const #{type}* origin);
      $
    end
  end # Forward


  class Range::Bidirectional < Range::Forward

    %i(popBack back backView).each {|s| redirect s, 1}

    def interface_definitions(stream)
      super
      stream << %$
        #{declare} void #{popBack}(#{type}* self);
        #{declare} const #{@container.element.type}* #{viewBack}(const #{type}* self);
      $
      stream << "#{declare} #{@container.element.type} #{back}(const #{type}* self);" if @container.element.cloneable?
    end

  end # Bidirectional


  class Range::RandomAccess < Range::Bidirectional

    %i(size get view).each {|s| redirect s, 1}

    def interface_definitions(stream)
      super
      stream << %$
        #{declare} size_t #{size}(const #{type}* self);
        #{declare} const #{@container.element.type}* #{view}(const #{type}* self, size_t index);
      $
      stream << "#{declare} #{@container.element.type} #{get}(const #{type}* self, size_t index);" if @container.element.cloneable?
    end

  end # RandomAccess


end # AutoC