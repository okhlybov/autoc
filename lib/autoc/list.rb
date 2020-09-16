require 'autoc/type'
require 'autoc/memory'


module AutoC


  #
  class List < Container

    %i(create destroy).each {|s| redirect(s, 1)}
    %i(clone equal).each {|s| redirect(s, 2)}

    alias default_create create

    def memory
      AutoC::Allocator.default
    end

    attr_reader :range

    def initialize(type, element, prefix: nil, deps: [])
      super(type, element, prefix, deps << memory)
      @range = Range.new(self)
      self.dependencies << @range
      @weak << @range
    end

    def interface
      @stream << %$
        typedef struct #{node} #{node};
        typedef struct #{type} #{type};
        struct #{type} {
          #{node}* head_node;
          size_t node_count;
        };
        struct #{node} {
          #{element.type} element;
          #{node}* next_node;
        };
        #{define} size_t #{size}(const #{type}* self) {
          assert(self);
          return self->node_count;
        }
        #{define} int #{empty}(const #{type}* self) {
          assert((self->node_count == 0) == (self->head_node == NULL));
          return #{size}(self) == 0;
        }
        #{define} #{type}* #{create}(#{type}* self) {
          assert(self);
          self->head_node = NULL;
          self->node_count = 0;
          return self;
        }
        #{define} int #{remove}(#{type}* self) {
          if(!#{empty}(self)) {
            #{node}* this_node = self->head_node; assert(this_node);
            self->head_node = self->head_node->next_node;
            #{element.destroy('this_node->element') if element.destructible?};
            #{memory.free(:this_node)};
            --self->node_count;
            return 1;
          } else return 0;
        }
        #{define} #{type}* #{destroy}(#{type}* self) {
          while(#{remove}(self));
          return NULL;
        }
        #{define} const #{element.type}* #{view}(const #{type}* self) {
          assert(!#{empty}(self));
          return &self->head_node->element;
        }
      $
      @stream << %$
        #{define} #{element.type} #{peek}(const #{type}* self) {
          #{element.type} result;
          const #{element.type}* e = #{view}(self);
          #{element.clone(:result, '*e')};
          return result;
        }
        #{define} #{element.type} #{pop}(#{type}* self) {
          #{element.type} result = #{peek}(self);
          return result;
        }
        #{define} void #{push}(#{type}* self, #{element.type} value) {
          #{node}* new_node = #{memory.allocate(node)};
          #{element.clone('new_node->element', :value)};
          new_node->next_node = self->head_node;
          self->head_node = new_node;
          ++self->node_count;
        }
      $ if element.cloneable?
      @stream << "#{declare} #{type}* #{clone}(#{type}* self, const #{type}* origin);" if cloneable?
      @stream << "#{declare} int #{equal}(const #{type}* self, const #{type}* other);" if equality_testable?
      @stream << %$
        #{declare} const #{element.type}* #{_findView}(const #{type}* self, #{element.type} element);
        #{define} int #{contains}(const #{type}* self, #{element.type} element) {
          return #{_findView}(self, element) != NULL;
        }
      $ if element.equality_testable?
    end

    def definitions
      @stream << %$
        #{define} #{type}* #{clone}(#{type}* self, const #{type}* origin) {
          #{range.type} r;
          #{node}* new_node;
          #{node}* last_node = NULL;
          for(#{range.create}(&r, self); !#{range.empty}(&r); #{range.popFront}(&r)) {
            const #{element.type}* e = #{range.frontView}(&r);
            new_node = #{memory.allocate(node)};
            #{element.clone('new_node->element', '*e')};
            new_node->next_node = NULL;
            if(last_node) {
              last_node->next_node = new_node;
              last_node = new_node;
            } else {
              self->head_node = last_node = new_node;
            }
          }
          self->node_count = #{size}(origin);
          return self;
        }
      $ if cloneable?
      @stream << %$
        #{define} int #{equal}(const #{type}* self, const #{type}* other) {
          if(#{size}(self) == #{size}(other)) {
            #{range.type} ra, rb;
            for(#{range.create}(&ra, self), #{range.create}(&rb, other); !#{range.empty}(&ra) && !#{range.empty}(&rb); #{range.popFront}(&ra), #{range.popFront}(&rb)) {
              const #{element.type}* a = #{range.frontView}(&ra);
              const #{element.type}* b = #{range.frontView}(&rb);
              if(!#{element.equal('*a', '*b')}) return 0;
            }
            return 1;
          } else return 0;
        }
      $ if equality_testable?
      @stream << %$
        #{define} const #{element.type}* #{_findView}(const #{type}* self, #{element.type} element) {
          #{range.type} r;
          for(#{range.create}(&r, self); !#{range.empty}(&r); #{range.popFront}(&r)) {
            const #{element.type}* e = #{range.frontView}(&r);
            if(#{element.equal('*e', :element)}) return e;
          }
          return NULL;
        }
      $ if element.equality_testable?
    end
  end # List

  class List::Range < Range::Forward

    def initialize(list)
      super(list, nil, [])
    end

    def interface
      @stream << %$
        typedef struct {
          const #{@container.node}* node;
        } #{type};
      $
      super
      @stream << %$
        #{define} #{type}* #{create}(#{type}* self, const #{@container.type}* container) {
          assert(self);
          assert(container);
          self->node = container->head_node;
          return self;
        }
        #{define} int #{empty}(const #{type}* self) {
          assert(self);
          return self->node == NULL;
        }
        #{define} #{type}* #{save}(#{type}* self, const #{type}* origin) {
          assert(self);
          assert(origin);
          *self = *origin;
          return self;
        }
        #{define} void #{popFront}(#{type}* self) {
          assert(!#{empty}(self));
          self->node = self->node->next_node;
        }
        #{define} const #{@container.element.type}* #{frontView}(const #{type}* self) {
          assert(!#{empty}(self));
          return &self->node->element;
        }
      $
      @stream << %$
        #{define} #{@container.element.type} #{front}(const #{type}* self) {
          #{@container.element.type} result;
          const #{@container.element.type}* e = #{frontView}(self);
          #{@container.element.clone(:result, '*e')};
          return result;
        }
      $ if @container.element.cloneable?
    end
  end # Range

end # AutoC