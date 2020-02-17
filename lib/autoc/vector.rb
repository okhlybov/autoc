require 'autoc/type'
require 'autoc/stdc'
require 'autoc/range'
require 'autoc/hasher'


module AutoC


  class Vector < Container

    %i(create createEx destroy).each {|s| def_redirector(s, 1)}
    %i(copy equal).each {|s| def_redirector(s, 2)}

    def initialize(type, element, auto_create = false, prefix: nil, deps: [])
      super(type, element, prefix, deps)
      if (@auto_create = auto_create)
        raise TraitError, 'can not create auto constructor due non-auto constructible element type' unless self.element.auto_constructible?
      else
        raise TraitError, 'can not create initializing constructor due to non-copyable element type' unless copyable?
      end
    end

    alias createAuto create

    def create(*args)
      @auto_create ? createAuto(*args) : createEx(*args)
    end

    def create_params
      @auto_create ? [STDC::SIZE_T] : [STDC::SIZE_T, element]
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
        #{inline} #{element.type} #{get}(const #{type}* self, size_t index) {
          #{element.type} value;
          const #{element.type}* p = #{view(:self, :index)};;
          #{element.copy(:value, '*p')};
          return value;
        }
        #{inline} void #{set}(#{type}* self, size_t index, #{element.type} value) {
          assert(self);
          assert(#{within}(self, index));
          #{element.destroy('self->elements[index]') if element.destructible?};
          #{element.copy('self->elements[index]', :value)};
        }
        #{declare} #{type}* #{destroy}(#{type}* self);
      $
      stream << %$
        #{declare} #{type}* #{createAuto}(#{type}* self, size_t size);
        #{declare} void #{resize}(#{type}* self, size_t new_size);
      $ if element.auto_constructible?
      stream << %$
        #{declare} #{type}* #{createEx}(#{type}* self, size_t size, const #{element.type} element);
        #{declare} #{type}* #{copy}(#{type}* self, const #{type}* origin);
      $ if copyable?
      stream << "#{declare} int #{equal}(const #{type}* self, const #{type}* other);" if equality_testable?
    end

    def definition(stream)
      stream << %$
        #{static} void #{allocate}(#{type}* self, size_t element_count) {
          assert(self);
          assert(element_count > 0);
          self->element_count = element_count;
          self->elements = (#{element.type}*)malloc(element_count*sizeof(#{element.type})); assert(self->elements);
        }
      $
      stream << %$
        #{define} #{type}* #{destroy}(#{type}* self) {
          size_t index, size;
          assert(self);
          size = #{size}(self);
          #{'for(index = 0; index < size; ++index)' + element.destroy("self->elements[index]") if element.destructible?};
          free(self->elements);
          return NULL;
        }
      $
      stream << %$
        #{define} #{type}* #{createAuto}(#{type}* self, size_t size) {
          size_t index;
          assert(self);
          #{allocate}(self, size);
          for(index = 0; index < size; ++index) {
            #{element.create('self->elements[index]')};
          }
          return self;
        }
        #{define} void #{resize}(#{type}* self, size_t new_size) {
          size_t index, size, from, to;
          assert(self);
          if((size = #{size}(self)) != new_size) {
            #{element.type}* elements = (#{element.type}*)malloc(new_size*sizeof(#{element.type})); assert(elements);
            from = AUTOC_MIN(size, new_size);
            to = AUTOC_MAX(size, new_size);
            for(index = 0; index < from; ++index) {
              elements[index] = self->elements[index];
            }
            if(size > new_size) {
              #{'for(index = from; index < to; ++index)' + element.destroy('self->elements[index]') if element.destructible?};
            } else {
              for(index = from; index < to; ++index) {
                #{element.create('elements[index]')};
              }
            }
            free(self->elements);
            self->elements = elements;
            self->element_count = new_size;
          }
        }
      $ if element.auto_constructible?
      stream << %$
        #{define} #{type}* #{createEx}(#{type}* self, size_t size, const #{element.type} value) {
          size_t index;
          assert(self);
          #{allocate}(self, size);
          for(index = 0; index < #{size}(self); ++index) {
            #{element.copy('self->elements[index]', :value)};
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
            #{element.copy('self->elements[index]', 'origin->elements[index]')};
          }
          return self;
        }
      $ if copyable?
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

    def range
      @range ||= Range.new(self)
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
            const #{@container.type}* iterable;
            size_t position;
          } #{type};
        $
      super
      stream << %$
      #{inline} #{type}* #{create}(#{type}* self, const #{@container.type}* iterable) {
            assert(self);
            assert(iterable);
            self->iterable = iterable;
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
            return #{@container.size('self->iterable')};
          }
          #{inline} const #{@container.element.type}* #{view}(const #{type}* self, size_t index) {
            assert(self);
            return #{@container.view('self->iterable', :index)};
          }
          #{inline} #{@container.element.type} #{get}(const #{type}* self, size_t index) {
            assert(self);
            return #{@container.get('self->iterable', :index)};
          }
          #{inline} int #{empty}(const #{type}* self) {
            assert(self);
            return !#{@container.within('self->iterable', 'self->position')};
          }
          #{inline} void #{popFront}(#{type}* self) {
            assert(self);
            ++self->position;
          }
          #{inline} #{@container.element.type} #{front}(const #{type}* self) {
            assert(self);
            return #{get}(self, self->position);
          }
          #{inline} const #{@container.element.type}* #{frontView}(const #{type}* self) {
            assert(self);
            return #{view}(self, self->position);
          }
          #{inline} void #{popBack}(#{type}* self) {
            assert(self);
            --self->position;
          }
          #{inline} #{@container.element.type} #{back}(const #{type}* self) {
            assert(self);
            return #{get}(self, self->position);
          }
          #{inline} const #{@container.element.type}* #{backView}(const #{type}* self) {
            assert(self);
            return #{view}(self, self->position);
          }
        $
    end

  end # Range


end # AutoC