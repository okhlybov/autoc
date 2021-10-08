# frozen_string_literal: true


require 'autoc/container'
require 'autoc/range'


module AutoC


  class List < Container

    def initialize(type, element, visibility = :public)
      super
      @range = Range.new(self, visibility)
      dependencies << range
      [default_create, destroy, @size, @empty, @contains].each(&:inline!)
      @compare = nil # Don't know how to order the vectors
    end

    def canonic_tag = "List<#{element.type}>"

    def composite_interface_declarations(stream)
      stream << %$
        /**
        * #{@defgroup} #{type} #{canonic_tag} :: singly linked list of elements of type #{element.type}
        * @{
        */
        typedef struct #{node} #{node}; /**< @private */
        typedef struct #{type} #{type}; /**< @private */
        struct #{type} {
          #{node}* head_node; /**< @private */
          size_t node_count; /**< @private */
        };
        /** @private */
        struct #{node} {
          #{element.type} element;
          #{node}* next_node;
        };
      $
      super
      stream << '/** @} */'
    end

    def composite_interface_definitions(stream)
      stream << %$
        /**
         * #{@addtogroup} #{type}
         * @{
         */
      $
      super
      stream << %$
        #{define(default_create)} {
          assert(self);
          self->head_node = NULL;
          self->node_count = 0;
        }
        /**
         * @brief Remove and destroy an element
         *
         * @return non-zero is there was an element and zero otherwise.
         */
        #{declare} int #{drop}(#{ptr_type} self);
        #{define(destroy)} {
          assert(self);
          while(#{drop}(self));
        }
        /**
         * @brief Remove and destroy all contained elements
         */
        #{define} void #{purge}(#{ptr_type} self) {
          #{destroy}(self);
          #{default_create}(self);
        }
        #{define(@size)} {
          assert(self);
          return self->node_count;
        }
        #{define(@empty)} {
          assert((self->node_count == 0) == (self->head_node == NULL));
          return #{size}(self) == 0;
        }
        /**
        * @brief Return a view of the top element or NULL is the list is empty
        */
        #{define} #{element.const_ptr_type} #{view}(#{const_ptr_type} self) {
          assert(self);
          return &(self->head_node->element);
        }
      $
      stream << %$
        /**
        * @brief Return a copy of the top element
        */
        #{define} #{element.type} #{peek}(#{const_ptr_type} self) {
          #{element.type} result;
          #{element.const_ptr_type} e;
          assert(!#{empty}(self));
          e = #{view}(self);
          #{element.copy(:result, '*e')};
          return result;
        }
        /**
        * @brief Return a copy of the top element and remove it from the list
        */
        #{define} #{element.type} #{pop}(#{ptr_type} self) {
          #{element.type} result;
          assert(!#{empty}(self));
          result = #{peek}(self);
          #{drop}(self);
          return result;
        }
        /**
        * @brief Put a copy of the element to the list top
        */
        #{define} void #{push}(#{ptr_type} self, #{element.const_type} value) {
          #{node}* new_node = #{memory.allocate(node)};
          #{element.copy('new_node->element', :value)};
          new_node->next_node = self->head_node;
          self->head_node = new_node;
          ++self->node_count;
        }
      $ if element.copyable?
      stream << %$
        /**
        * @brief Return a view of the contained element equal to the specified element or NULL is no such element found
        */
        #{declare} #{element.const_ptr_type} #{find_view}(#{const_ptr_type} self, #{element.const_type} value);
        #{define(@contains)} {
          return #{find_view}(self, value) != NULL;
        }
        /**
        * @brief Remove and destroy the first contained element equal to the specified element
        */
        #{declare} int #{remove}(#{ptr_type} self, #{element.const_type} value);
      $ if element.comparable?
      stream << '/** @} */'
    end

    def definitions(stream)
      super
      stream << %$
        #{define} int #{drop}(#{ptr_type} self) {
          if(!#{empty}(self)) {
            #{node}* this_node = self->head_node; assert(this_node);
            self->head_node = self->head_node->next_node;
            #{element.destroy('this_node->element') if element.destructible?};
            #{memory.free(:this_node)};
            --self->node_count;
            return 1;
          } else return 0;
        }
      $
      stream << %$
        #{define(copy)} {
          #{create}(self);
          for(#{range.type} r = #{get_range}(source); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{push}(self, *#{range.front_view}(&r));
          }
        }
      $ if copyable?
      stream << %$
        #{define(equal)} {
          if(#{size}(self) == #{size}(other)) {
            for(#{range.type} ra = #{get_range}(self), rb = #{get_range}(other); !#{range.empty}(&ra) && !#{range.empty}(&rb); #{range.pop_front}(&ra), #{range.pop_front}(&rb)) {
              const #{element.type}* a = #{range.front_view}(&ra);
              const #{element.type}* b = #{range.front_view}(&rb);
              if(!#{element.equal('*a', '*b')}) return 0;
            }
            return 1;
          } else return 0;
        }
      $ if comparable?
      stream << %$
        #{define} #{element.const_ptr_type} #{find_view}(#{const_ptr_type} self, #{element.const_type} value) {
          for(#{range.type} r = #{get_range}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{element.const_ptr_type} e = #{range.front_view}(&r);
            if(#{element.equal('*e', :value)}) return e;
          }
          return NULL;
        }
        #{define} int #{remove}(#{ptr_type} self, #{element.const_type} value) {
          #{node} *node, *prev_node;
          int removed = 0;
          assert(self);
          node = self->head_node;
          prev_node = NULL;
          while(node) {
            if(#{element.equal('node->element', :value)}) {
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
      $ if element.comparable?
    end


    class List::Range < Range::Forward

      def initialize(*args)
        super
        [custom_create, @empty, @save, @pop_front, @front_view, @front].each(&:inline!)
      end

      def composite_interface_declarations(stream)
        stream << %$
          /**
           * #{@defgroup} #{type} #{canonic_tag} :: range iterator for the iterable container #{iterable.canonic_tag}
           * @{
           */
          typedef struct {
            #{iterable.node}* node; /**< @private */
          } #{type};
        $
        super
        stream << '/** @} */'
      end

      def composite_interface_definitions(stream)
        stream << %$
          /**
           * #{@addtogroup} #{type}
           * @{
           */
        $
        super
        stream << %$
          #{define(custom_create)} {
            assert(self);
            assert(iterable);
            self->node = iterable->head_node;
          }
          #{define(@empty)} {
            assert(self);
            return self->node == NULL;
          }
          #{define(@save)} {
            assert(self);
            assert(origin);
            *self = *origin;
          }
          #{define(@pop_front)} {
            assert(!#{empty}(self));
            self->node = self->node->next_node;
          }
          #{define(@front_view)} {
            assert(!#{empty}(self));
            return &self->node->element;
          }
        $
        stream << '/** @} */'
      end

    end


  end


end