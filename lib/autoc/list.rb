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

    def interface_declarations(stream)
      super
      stream << %$
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
      $
    end

    def interface(stream)
      super
      stream << %$
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
        #{define} int #{drop}(#{type}* self) {
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
          while(#{drop}(self));
          return NULL;
        }
        #{define} const #{element.type}* #{view}(const #{type}* self) {
          assert(!#{empty}(self));
          return &self->head_node->element;
        }
      $
      stream << %$
        #{define} #{element.type} #{peek}(const #{type}* self) {
          #{element.type} result;
          const #{element.type}* e;
          assert(!#{empty}(self));
          e = #{view}(self);
          #{element.clone(:result, '*e')};
          return result;
        }
        #{define} #{element.type} #{pop}(#{type}* self) {
          #{element.type} result;
          assert(!#{empty}(self));
          result = #{peek}(self);
          #{drop}(self);
          return result;
        }
        #{define} void #{push}(#{type}* self, const #{element.type} value) {
          #{node}* new_node = #{memory.allocate(node)};
          #{element.clone('new_node->element', :value)};
          new_node->next_node = self->head_node;
          self->head_node = new_node;
          ++self->node_count;
        }
      $ if element.cloneable?
      stream << %$
        #{declare} const #{element.type}* #{findView}(const #{type}* self, const #{element.type} what);
        #{define} int contains(const #{type}* self, const #{element.type} what) {
          return #{findView}(self, what) != NULL;
        }
        #{declare} int #{remove}(#{type}* self, const #{element.type} what);
      $ if element.equality_testable?
      stream << "#{declare} #{type}* #{clone}(#{type}* self, const #{type}* origin);" if cloneable?
      stream << "#{declare} int #{equal}(const #{type}* self, const #{type}* other);" if equality_testable?
    end

    def definitions(stream)
      super
      stream << %$
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
      stream << %$
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
      stream << %$
        #{define} const #{element.type}* #{findView}(const #{type}* self, const #{element.type} what) {
          #{range.type} r;
          for(#{range.create}(&r, self); !#{range.empty}(&r); #{range.popFront}(&r)) {
            const #{element.type}* e = #{range.frontView}(&r);
            if(#{element.equal('*e', :what)}) return e;
          }
          return NULL;
        }
        #{define} int #{remove}(#{type}* self, const #{element.type} what) {
          #{node} *node, *prev_node;
          int removed = 0;
          assert(self);
          node = self->head_node;
          prev_node = NULL;
          while(node) {
            if(#{element.equal('node->element', :what)}) {
              #{node}* this_node;
              if(prev_node) {
                this_node = prev_node->next_node = node->next_node;
              } else {
                this_node = self->head_node = node->next_node;
              }
              removed = 1;
              --self->node_count;
              #{element.destroy('node->element') if element.destructible?};
              #{memory.free(:node)};
              node = this_node;
              if(removed) break;
            } else {
              prev_node = node;
              node = node->next_node;
            }
          }
          return removed;
        }
      $ if element.equality_testable?
    end
  end # List

  class List::Range < Range::Forward

    def initialize(list)
      super(list, nil, [])
    end

    def interface_declarations(stream)
      super
      stream << %$
        typedef struct {
          const #{@container.node}* node;
        } #{type};
      $
    end

    def interface_definitions(stream)
      super
      stream << %$
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
      stream << %$
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