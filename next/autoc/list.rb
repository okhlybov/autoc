# frozen_string_literal: true


require 'autoc/container'
require 'autoc/range'


module AutoC


  # Generator for the linked list container type.
  class List < Container

    prepend Container::Hashable
    prepend Container::Sequential

    attr_reader :_node

    def initialize(type, element, visibility = :public)
      super
      @_node = decorate_identifier(:_node)
      dependencies << (@range = Range.new(self, visibility))
    end

    def orderable? = false # No idea how to compute the ordering of this container

    def canonic_tag = "List<#{element.type}>"

    def composite_interface_declarations(stream)
      stream << %$
        /**
          #{defgroup}

          @brief Singly linked list of elements of type #{element.type}

          For iteration over the list elements refer to @ref #{range.type}.

          @see C++ [std::forward_list<T>](https://en.cppreference.com/w/cpp/container/forward_list)

          @since 2.0
        */
        typedef struct #{_node} #{_node}; /**< @private */
        typedef struct #{type} #{type}; /**< @private */
        /**
          #{ingroup}
          @brief Opaque structure holding state of the list
          @since 2.0
        */
        struct #{type} {
          #{_node}* head_node; /**< @private */
          size_t node_count; /**< @private */
        };
        /** @private */
        struct #{_node} {
          #{element.type} element;
          #{_node}* next_node;
        };
      $
      super
    end
    
    private def configure
      super
      def_method :void, :_drop_front, { self: type }, visibility: :private do
        code %{
          #{_node}* this_node;
          assert(!#{empty}(self));
          this_node = self->head_node; assert(this_node);
          self->head_node = self->head_node->next_node;
          #{memory.free(:this_node)};
          --self->node_count;
        }
      end
      def_method :void, :purge, { self: type } do
        inline_code %{
          assert(self);
          #{destroy}(self);
          #{default_create}(self);
        }
        header %{
          @brief Remove and destroy all contained elements

          @param[in] self list to be purged

          The elements are destroyed with respective destructor.

          After call to this function the list will remain intact yet contain zero elements.

          @since 2.0
        }
      end
      def_method element.const_ptr_type, :view_front, { self: const_type } do
        inline_code %{
          assert(!#{empty}(self));
          return &(self->head_node->element);
        }
        header %{
          @brief Get a view of the front element

          @param[in] self list to get element from
          @return a view of a front element

          This function is used to get a constant reference (in form of the C pointer) to the front value contained in `self`.
          Refer to @ref #{take_front} to get an independent copy of that element.

          It is generally not safe to bypass the constness and to alter the value in place (although no one prevents to).

          @note List must not be empty (see @ref #{empty}).

          @since 2.0
        }
      end
      def_method element.type, :pull_front, { self: type } do
        code %{
          #{element.type} value;
          assert(self);
          assert(!#{empty}(self));
          value = *#{view_front}(self);
          #{_drop_front}(self);
          return value;
        }
        header %{
          @brief Extract front element

          @param[in] self list to extract element from
          @return front element

          This function returns and removes front element from the list.
          Note that contrary to @ref #{take_front} no copy operation is performed - it is the contained value itself that is returned.

          @note List must not be empty (see @ref #{empty}).

          @since 2.0
        }
      end
      def_method :void, :pop_front, { self: type } do
        code %{
          #{element.type} value;
          assert(self);
          assert(!#{empty}(self));
          value = *#{view_front}(self);
          #{element.destroy(:value) if element.destructible?};
          #{_drop_front}(self);
        }
        header %{
          @brief Drop front element

          @param[in] self list to drop element from

          This function removes front element from the list and destroys it with the respective destructor.

          @note List must not be empty (see @ref #{empty}).

          @since 2.0
        }
      end
      def_method element.type, :take_front, { self: const_type }, require:-> { element.copyable? } do
        code %{
          #{element.type} result;
          #{element.const_ptr_type} e;
          assert(self);
          assert(!#{empty}(self));
          e = #{view_front}(self);
          #{element.copy(:result, '*e')};
          return result;
        }
        header %{
          @brief Get front element

          @param[in] self list to get element from
          @return a *copy* of a front element

          This function is used to get a *copy* of the front value contained in `self`.
          Refer to @ref #{view_front} to get a view of that element without making an independent copy.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @note List must not be empty (see @ref #{empty}).

          @since 2.0
        }
      end
      def_method :void, :push_front, { self: type, value: element.const_type }, require:-> { element.copyable? } do
        code %{
          #{_node}* new_node;
          assert(self);
          new_node = #{memory.allocate(_node)};
          #{element.copy('new_node->element', :value)};
          new_node->next_node = self->head_node;
          self->head_node = new_node;
          ++self->node_count;
        }
        header %{
          @brief Put element

          @param[in] self vector to put element into
          @param[in] value value to put

          This function pushes a *copy* of the specified value to the front position of `self`.
          It becomes a new front element.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @since 2.0
        }
      end
      def_method :int, :remove, { self: type, value: element.const_type }, require:-> { element.comparable? } do
        code %{
          #{_node} *node, *prev_node;
          int removed = 0;
          assert(self);
          node = self->head_node;
          prev_node = NULL;
          while(node) {
            if(#{element.equal('node->element', :value)}) {
              #{_node}* this_node;
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
        header %{
          @brief Remove element

          @param[in] self list to remove element from
          @param[in] value value to search in list
          @return non-zero value on successful removal and zero value otherwise

          This function searches `self` for a first element equal to the specified `value` and removes it from the list.
          The removed element is destroyed with respective destructor.

          The function return value is non-zero if such element was found and removed and zero value otherwise.

          This function requires the element type to be *comparable* (i.e. to have a well-defined equality operation).

          @since 2.0
        }
      end
      @default_create.inline_code %{
        assert(self);
        self->head_node = NULL;
        self->node_count = 0;
      }
      @destroy.inline_code %{
        assert(self);
        while(!#{empty}(self)) #{pop_front}(self);
      }
      @size.inline_code %{
        assert(self);
        return self->node_count;
      }
      @empty.inline_code %{
        assert(self);
        assert((self->node_count == 0) == (self->head_node == NULL));
        return #{size}(self) == 0;
      }
      @copy.code %{
        #{range.type} r;
        assert(self);
        assert(source);
        #{create}(self);
        for(r = #{get_range}(source); !#{range.empty}(&r); #{range.pop_front}(&r)) {
          #{push_front}(self, *#{range.view_front}(&r));
        }
      }
      @equal.code %{
        #{range.type} ra, rb;
        assert(self);
        assert(other);
        if(#{size}(self) == #{size}(other)) {
          for(ra = #{get_range}(self), rb = #{get_range}(other); !#{range.empty}(&ra) && !#{range.empty}(&rb); #{range.pop_front}(&ra), #{range.pop_front}(&rb)) {
            #{element.const_ptr_type} a = #{range.view_front}(&ra);
            #{element.const_ptr_type} b = #{range.view_front}(&rb);
            if(!#{element.equal('*a', '*b')}) return 0;
          }
          return 1;
        } else return 0;
      }
    end

    class List::Range < Range::Forward

      def _node = iterable._node

      def composite_interface_declarations(stream)
        stream << %$
          /**
            #{defgroup}
            @ingroup #{iterable.type}

            @brief #{canonic_desc}

            This range implements the @ref #{archetype} archetype.

            @see @ref Range

            @since 2.0
          */
          /**
            #{ingroup}
            @brief Opaque structure holding state of the list's range
            @since 2.0
          */
          typedef struct {
            #{_node}* node; /**< @private */
          } #{type};
        $
        super
      end

      private def configure
        super
        @custom_create.inline_code %{
          assert(self);
          assert(iterable);
          self->node = iterable->head_node;
        }
        @empty.inline_code %{
          assert(self);
          return self->node == NULL;
        }
        @save.inline_code %{
          assert(self);
          assert(origin);
          *self = *origin;
        }
        @pop_front.inline_code %{
          assert(self);
          assert(!#{empty}(self));
          self->node = self->node->next_node;
        }
        @view_front.inline_code %{
          assert(self);
          assert(!#{empty}(self));
          return &self->node->element;
        }
      end
    end # Range


  end # List


end