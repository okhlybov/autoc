require 'autoc/type'
require 'autoc/memory'


module AutoC


  #
  class List < Container

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

    def interface(stream)
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
        #{inline} #{type}* #{create}(#{type}* self) {
          assert(self);
          self->head_node = NULL;
          self->node_count = 0;
        }
        #{declare} #{type}* #{destroy}(#{type}* self);
      $
    end

    def definition(stream)
      stream << %$
        #{define} #{type}* #{destroy}(#{type}* self) {
          #{node}* node;
          assert(self);
          node = self->head_node;
          while(node) {
            #{node}* this_node = node;
            node = node->next_node;
            #{element.destroy('this_node->element') if element.destructible?};
            #{memory.free(:this_node)};
          }
          return NULL;
        }
      $
    end
  end # List

  class List::Range < Range::Input

    alias declare inline

    def initialize(list)
      super(list, nil, [])
    end

    def interface(stream)
      stream << %$
        typedef struct {
          const #{@container.node}* node;
        } #{type};
      $
      super
      stream << %$
        #{inline} #{type}* #{create}(#{type}* self, const #{@container.type}* container) {
          assert(self);
          assert(container);
          self->node = container->head_node;
          return self;
        }
        #{inline} int #{empty}(const #{type}* self) {
          assert(self);
          return self->node == NULL;
        }
        #{inline} void #{popFront}(#{type}* self) {
          assert(!#{empty}(self));
          self->node = self->node->next_node;
        }
        #{inline} const #{@container.element.type}* #{frontView}(const #{type}* self) {
          assert(!#{empty}(self));
          return &self->node->element;
        }
      $
      stream << %$
        #{inline} #{@container.element.type} #{front}(const #{type}* self) {
          #{@container.element.type} result;
          const #{@container.element.type}* e = #{frontView}(self);
          #{@container.element.clone(:result, '*e')};
          return result;
        }
      $ if @container.element.cloneable?
    end
  end # Range

end # AutoC