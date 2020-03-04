require 'autoc/type'
require 'autoc/stdc'
require 'autoc/range'
require 'autoc/memory'


module AutoC


  class Vector < Container

    include ConstructibleAdapter

    %i(destroy).each {|s| redirect(s, 1)}
    %i(copy equal).each {|s| redirect(s, 2)}

    def memory
      AutoC::Allocator.default
    end

    # @note Vector has no default constructor regardless of the element type traits since it requires the size value.
    def default_constructible?
      false
    end

    # @note Vector itself has custom constructor only if the element type has copy constructor defined.
    def custom_constructible?
      element.cloneable?
    end

    attr_reader :range

    def initialize(type, element, prefix: nil, deps: [])
      super(type, element, prefix, deps << memory)
      raise TraitError, 'element type must have default constructor or copy constructor' unless self.element.default_constructible? || self.element.cloneable?
      @default_create = self.element.default_constructible? ? :create : nil
      @custom_create = if self.element.cloneable?
        self.custom_create_params = [SIZE_T, self.element]
        :createEx
      else
        nil
      end
      @range = Range.new(self)
    end

    def interface(stream)
      stream << %$
        typedef struct {
          #{element.type}* elements;
          size_t element_count;
        } #{type};
        #{inline} size_t #{size}(const #{type}* self) {
          assert(self);
          return self->element_count;
        }
        #{inline} int #{within}(const #{type}* self, size_t index) {
          assert(self);
          return index < #{size}(self);
        }
        #{inline} const #{element.type}* #{view}(const #{type}* self, size_t index) {
          assert(self);
          assert(#{within}(self, index));
          return &self->elements[index];
        }
        #{declare} #{type}* #{destroy}(#{type}* self);
      $
      stream << %$
        #{declare} #{type}* #{send(@default_create)}(#{type}* self, size_t size);
        #{declare} void #{resize}(#{type}* self, size_t new_size);
      $ if element.default_constructible?
      stream << %$
        #{declare} #{type}* #{send(@custom_create)}(#{type}* self, size_t size, const #{element.type} element);
        #{declare} #{type}* #{copy}(#{type}* self, const #{type}* origin);
        #{inline} #{element.type} #{get}(const #{type}* self, size_t index) {
          #{element.type} value;
          const #{element.type}* p = #{view(:self, :index)};
          #{element.clone(:value, '*p')};
          return value;
        }
        #{inline} void #{set}(#{type}* self, size_t index, #{element.type} value) {
          assert(self);
          assert(#{within}(self, index));
          #{element.destroy('self->elements[index]') if element.destructible?};
          #{element.clone('self->elements[index]', :value)};
        }
      $ if element.cloneable?
      stream << "#{declare} int #{equal}(const #{type}* self, const #{type}* other);" if equality_testable?
    end

    def definition(stream)
      stream << %$
        #{static} void #{allocate}(#{type}* self, size_t element_count) {
          assert(self);
          assert(element_count > 0);
          self->element_count = element_count;
          self->elements = #{memory.allocate(element.type)}; assert(self->elements);
        }
      $
      stream << %$
        #{define} #{type}* #{destroy}(#{type}* self) {
          assert(self);
      $
      stream << %${
          size_t index, size = #{size}(self);
          for(index = 0; index < size; ++index) #{element.destroy("self->elements[index]")};
      }$ if element.destructible?
      stream << %$
          #{memory.free('self->elements')};
          return NULL;
        }
      $
      stream << %$
        #{define} #{type}* #{send(@default_create)}(#{type}* self, size_t size) {
          size_t index;
          assert(self);
          #{allocate}(self, size);
          for(index = 0; index < size; ++index) {
            #{element.default_create('self->elements[index]')};
          }
          return self;
        }
        #{define} void #{resize}(#{type}* self, size_t new_size) {
          size_t index, size, from, to;
          assert(self);
          if((size = #{size}(self)) != new_size) {
            #{element.type}* elements = #{memory.allocate(element.type)}; assert(elements);
            from = AUTOC_MIN(size, new_size);
            to = AUTOC_MAX(size, new_size);
            for(index = 0; index < from; ++index) {
              elements[index] = self->elements[index];
            }
            if(size > new_size) {
              #{'for(index = from; index < to; ++index)' + element.destroy('self->elements[index]') if element.destructible?};
            } else {
              for(index = from; index < to; ++index) {
                #{element.default_create('elements[index]')};
              }
            }
            #{memory.free('self->elements')};
            self->elements = elements;
            self->element_count = new_size;
          }
        }
      $ if element.default_constructible?
      stream << %$
        #{define} #{type}* #{send(@custom_create)}(#{type}* self, size_t size, const #{element.type} value) {
          size_t index;
          assert(self);
          #{allocate}(self, size);
          for(index = 0; index < size; ++index) {
            #{element.clone('self->elements[index]', :value)};
          }
          return self;
        }
        #{define} #{type}* #{copy}(#{type}* self, const #{type}* origin) {
          size_t index, size;
          assert(self);
          assert(origin);
          #{destroy}(self);
          #{allocate}(self, size = #{size}(origin));
          for(index = 0; index < size; ++index) {
            #{element.clone('self->elements[index]', 'origin->elements[index]')};
          }
          return self;
        }
      $ if element.cloneable?
      stream << %$
        #{define} int #{equal}(const #{type}* self, const #{type}* other) {
          size_t index, size;
          assert(self);
          assert(other);
          if(#{size}(self) == (size = #{size}(other))) {
            for(index = 0; index < size; ++index) {
              if(!(#{element.equal('self->elements[index]', 'other->elements[index]')})) return 0;
            }
            return 1;
          } else return 0;
        }
      $ if equality_testable?
    end

  end # Vector


  class Vector::Range < Range::RandomAccess

    def initialize(vector)
      super(vector, nil, [])
    end

    alias declare inline

    def interface(stream)
      stream << %$
        typedef struct {
          const #{@container.type}* container;
          size_t position;
        } #{type};
      $
      super
      stream << %$
        #{inline} #{type}* #{create}(#{type}* self, const #{@container.type}* container) {
            assert(self);
            assert(container);
            self->container = container;
            self->position = 0;
            return self;
        }
        #{inline} #{type}* #{save}(#{type}* self, const #{type}* origin) {
          assert(self);
          assert(origin);
          *self = *origin;
          return self;
        }
        #{inline} size_t #{size}(const #{type}* self) {
          assert(self);
          return #{@container.size('self->container')};
        }
        #{inline} const #{@container.element.type}* #{view}(const #{type}* self, size_t index) {
          assert(self);
          return #{@container.view('self->container', :index)};
        }
        #{inline} int #{empty}(const #{type}* self) {
          assert(self);
          return !#{@container.within('self->container', 'self->position')};
        }
        #{inline} void #{popFront}(#{type}* self) {
          assert(self);
          ++self->position;
        }
        #{inline} const #{@container.element.type}* #{frontView}(const #{type}* self) {
          assert(self);
          return #{view}(self, self->position);
        }
        #{inline} void #{popBack}(#{type}* self) {
          assert(self);
          --self->position;
        }
        #{inline} const #{@container.element.type}* #{backView}(const #{type}* self) {
          assert(self);
          return #{view}(self, self->position);
        }
      $
      stream << %$
        #{inline} #{@container.element.type} #{get}(const #{type}* self, size_t index) {
            assert(self);
            return #{@container.get('self->container', :index)};
        }
        #{inline} #{@container.element.type} #{front}(const #{type}* self) {
          assert(self);
          return #{get}(self, self->position);
        }
        #{inline} #{@container.element.type} #{back}(const #{type}* self) {
          assert(self);
          return #{get}(self, self->position);
        }
      $ if @container.element.cloneable?
    end

  end # Range


end # AutoC