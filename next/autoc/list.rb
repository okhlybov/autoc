require 'autoc/type'
require 'autoc/memory'
require 'autoc/range'


module AutoC


  class List < Container

    #
    attr_reader :range

    def initialize(type, element)
      super
      @range = Range.new(self)
      @initial_dependencies << range
    end

    def interface_declarations(stream)
      stream << %$
        /**
        * @defgroup #{type} Singly linked list of values of type <#{element.type}>
        * @{
        */
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
      super
      stream << '/** @} */'
    end

    def interface_definitions(stream)
      super
      stream << %$
        /**
         * @addtogroup #{type}
         * @{
         */
        /**
         * @brief Create a new empty list at self
         */
        #{define(default_create)} {
          assert(self);
          self->head_node = NULL;
          self->node_count = 0;
        }
        /**
         * @brief
         */
        #{declare} int #{drop}(#{ptr_type} self);
        /**
         * @brief Destroy the list at self along with its elements and free storage
         */
        #{define(destroy)} {
          assert(self);
          while(#{drop}(self));
        }
        /**
         * @brief Return number of elements contained
         */
        #{define} size_t #{size}(#{const_ptr_type} self) {
          assert(self);
          return self->node_count;
        }
        /**
         * @brief Return true if list contains at least one element
         */
        #{define} int #{empty}(#{const_ptr_type} self) {
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
        * @brief Return true if two lists are equal by contents
        */
        #{declare(equal)};
      $ if comparable?
      stream << %$
        /**
        * @brief Return a view of the contained element equal to the specified element or NULL is no such element found
        */
        #{declare} #{element.const_ptr_type} #{findView}(#{const_ptr_type} self, #{element.const_type} what);
        /**
        * @brief Return true if there is at least one the contained element equal to the specified element
        */
        #{define} int contains(#{const_ptr_type} self, #{element.const_type} what) {
          return #{findView}(self, what) != NULL;
        }
        /**
        * @brief Remove and destroy the first contained element equal to the specified element
        */
        #{declare} int #{remove}(#{ptr_type} self, #{element.const_type} what);
      $ if element.comparable?
      stream << %$
        /**
        * @brief Create a new list containing copies of the original list's elements
        */
        #{declare(copy)};
      $ if copyable?
      stream << %$/** @} */$
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
        #{define(equal)} {
          if(#{size}(self) == #{size}(other)) {
            #{range.type} ra, rb;
            for(#{range.create}(&ra, self), #{range.create}(&rb, other); !#{range.empty}(&ra) && !#{range.empty}(&rb); #{range.pop_front}(&ra), #{range.pop_front}(&rb)) {
              const #{element.type}* a = #{range.front_view}(&ra);
              const #{element.type}* b = #{range.front_view}(&rb);
              if(!#{element.equal('*a', '*b')}) return 0;
            }
            return 1;
          } else return 0;
        }
      $ if comparable?
      stream << %$
        #{define} #{element.const_ptr_type} #{findView}(#{const_ptr_type} self, #{element.const_type} what) {
          #{range.type} r;
          for(#{range.create}(&r, self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{element.const_ptr_type} e = #{range.front_view}(&r);
            if(#{element.equal('*e', :what)}) return e;
          }
          return NULL;
        }
        #{define} int #{remove}(#{ptr_type} self, #{element.const_type} what) {
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
      $ if element.comparable?
    end


    class List::Range < Range::Forward

      def interface_declarations(stream)
        stream << %$
          /**
          * @defgroup #{type} Range iterator for <#{iterable.type}> iterable container
          * @{
          */
          typedef struct {
            #{iterable.node}* node;
          } #{type};
        $
        super
        stream << '/** @} */'
      end
  
      def interface_definitions(stream)
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
        stream << %$
          #{define(@front)} {
            #{iterable.element.type} result;
            const #{iterable.element.type}* e = #{@front_view}(self);
            #{iterable.element.copy(:result, '*e')};
            return result;
          }
        $ if iterable.element.copyable?
      end
  
      def setup_interface_declarations
        @declare = @define = :AUTOC_INLINE
      end

      def setup_interface_definitions
        @declare = @define = :AUTOC_INLINE
      end

    end


  end


end