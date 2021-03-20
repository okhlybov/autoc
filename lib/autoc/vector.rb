require 'autoc/type'
require 'autoc/stdc'
require 'autoc/range'
require 'autoc/memory'


module AutoC


  class Vector < Container

    include ConstructibleAdapter

    %i(destroy).each {|s| redirect(s, 1)}
    %i(clone equal).each {|s| redirect(s, 2)}

    # @note Vector is default constructible regardless of the element's traits since zero-size instance is allowed.
    def default_constructible?
      true
    end

    # @note Vector itself has custom constructor only if the element type has default constructor defined.
    def custom_constructible?
      element.default_constructible?
    end

    attr_reader :range

    def initialize(type, element, prefix: nil, deps: [])
      super(type, element, prefix, deps << (@range = Range.new(self)))
      @weak << range
      @default_create = :create0
      if custom_constructible?
        @custom_create = :create
        self.custom_create_params = [STDC::SIZE_T]
      end
    end

    def interface_declarations(stream)
      super
      stream << %$
        typedef struct {
          #{element.type}* elements;
          size_t element_count;
        } #{type};
      $
    end

    def interface_definitions(stream)
      super
      stream << %$
        #{define} size_t #{size}(const #{type}* self) {
          assert(self);
          return self->element_count;
        }
        #{define} int #{within}(const #{type}* self, size_t index) {
          assert(self);
          return index < #{size}(self);
        }
        #{define} const #{element.type}* #{view}(const #{type}* self, size_t index) {
          assert(self);
          assert(#{within}(self, index));
          return &self->elements[index];
        }
        #{define} #{type}* #{send(@default_create)}(#{type}* self) {
          assert(self);
          self->element_count = 0;
          self->elements = NULL;
          return self;
        }
        #{declare} #{type}* #{destroy}(#{type}* self);
      $
      stream << %$
        #{declare} #{type}* #{send(@custom_create)}(#{type}* self, size_t size);
      $ if custom_constructible?
      stream << %$
        #{declare} void #{resize}(#{type}* self, size_t new_size);
      $ if element.default_constructible?
      stream << %$
        #{declare} #{type}* #{createEx}(#{type}* self, size_t size, const #{element.type} value);
        #{declare} #{type}* #{clone}(#{type}* self, const #{type}* origin);
        #{define} #{element.type} #{get}(const #{type}* self, size_t index) {
          #{element.type} value;
          const #{element.type}* p = #{view(:self, :index)};
          #{element.clone(:value, '*p')};
          return value;
        }
        #{define} void #{set}(#{type}* self, size_t index, const #{element.type} value) {
          assert(self);
          assert(#{within}(self, index));
          #{element.destroy('self->elements[index]') if element.destructible?};
          #{element.clone('self->elements[index]', :value)};
        }
      $ if element.cloneable?
      stream << "#{declare} int #{equal}(const #{type}* self, const #{type}* other);" if equality_testable?
      stream << "#{declare} void #{sort}(#{type}* self, int direction);" if element.comparable?
    end

    def definitions(stream)
      super
      stream << %$
        static void #{allocate}(#{type}* self, size_t element_count) {
          assert(self);
          if((self->element_count = element_count) > 0) {
            self->elements = #{memory.allocate(element.type, :element_count)}; assert(self->elements);
          } else {
            self->elements = NULL;
          }
        }
      $
      stream << %$
        #{define} #{type}* #{destroy}(#{type}* self) {
          assert(self);
      $
        stream << %${
            size_t index, size = #{size}(self);
            for(index = 0; index < size; ++index) #{element.destroy('self->elements[index]')};
        }$ if element.destructible?
      stream << %$
          #{memory.free('self->elements')};
          return NULL;
        }
      $
      stream << %$
        #{define} #{type}* #{send(@custom_create)}(#{type}* self, size_t size) {
          size_t index;
          assert(self);
          #{allocate}(self, size);
          for(index = 0; index < size; ++index) {
            #{element.default_create('self->elements[index]')};
          }
          return self;
        }
      $ if custom_constructible?
      stream << %$
        #{define} void #{resize}(#{type}* self, size_t new_size) {
          size_t index, size, from, to;
          assert(self);
          if((size = #{size}(self)) != new_size) {
            #{element.type}* elements = #{memory.allocate(element.type, :new_size)}; assert(elements);
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
        #{define} #{type}* #{createEx}(#{type}* self, size_t size, const #{element.type} value) {
          size_t index;
          assert(self);
          #{allocate}(self, size);
          for(index = 0; index < size; ++index) {
            #{element.clone('self->elements[index]', :value)};
          }
          return self;
        }
        #{define} #{type}* #{clone}(#{type}* self, const #{type}* origin) {
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
      stream << %$
        static int #{ascend}(void* lp_, void* rp_) {
          #{element.type}* lp = (#{element.type}*)lp_;
          #{element.type}* rp = (#{element.type}*)rp_;
          if(#{element.equal('*lp', '*rp')}) {
            return 0;
          } else if(#{element.less('*lp', '*rp')}) {
            return -1;
          } else {
            return +1;
          }
        }
        static int #{descend}(void* lp_, void* rp_) {
          return -#{ascend}(lp_, rp_);
        }
        #include <stdlib.h>
        #{define} void #{sort}(#{type}* self, int order) {
          typedef int (*F)(const void*, const void*);
          assert(self);
          qsort(self->elements, #{size}(self), sizeof(#{element.type}), order > 0 ? (F)#{ascend} : (F)#{descend});
        }
      $ if element.comparable?
    end

  end # Vector


  class Vector::Range < Range::RandomAccess

    def initialize(vector)
      super(vector, nil, [])
    end

    def interface_declarations(stream)
      super
      stream << %$
        typedef struct {
          const #{@container.type}* container;
          size_t position;
        } #{type};
      $
    end

    def interface_definitions(stream)
      super
      stream << %$
        #{define} #{type}* #{create}(#{type}* self, const #{@container.type}* container) {
            assert(self);
            assert(container);
            self->container = container;
            self->position = 0;
            return self;
        }
        #{define} #{type}* #{save}(#{type}* self, const #{type}* origin) {
          assert(self);
          assert(origin);
          *self = *origin;
          return self;
        }
        #{define} size_t #{size}(const #{type}* self) {
          assert(self);
          return #{@container.size('self->container')};
        }
        #{define} const #{@container.element.type}* #{view}(const #{type}* self, size_t index) {
          assert(self);
          return #{@container.view('self->container', :index)};
        }
        #{define} int #{empty}(const #{type}* self) {
          assert(self);
          return !#{@container.within('self->container', 'self->position')};
        }
        #{define} void #{popFront}(#{type}* self) {
          assert(self);
          ++self->position;
        }
        #{define} const #{@container.element.type}* #{viewFront}(const #{type}* self) {
          assert(self);
          return #{view}(self, self->position);
        }
        #{define} void #{popBack}(#{type}* self) {
          assert(self);
          --self->position;
        }
        #{define} const #{@container.element.type}* #{viewBack}(const #{type}* self) {
          assert(self);
          return #{view}(self, self->position);
        }
      $
      stream << %$
        #{define} #{@container.element.type} #{get}(const #{type}* self, size_t index) {
            assert(self);
            return #{@container.get('self->container', :index)};
        }
        #{define} #{@container.element.type} #{front}(const #{type}* self) {
          assert(self);
          return #{get}(self, self->position);
        }
        #{define} #{@container.element.type} #{back}(const #{type}* self) {
          assert(self);
          return #{get}(self, self->position);
        }
      $ if @container.element.cloneable?
    end

  end # Range


end # AutoC