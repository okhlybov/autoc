# frozen_string_literal: true


require 'autoc/ranges'
require 'autoc/sequential'
require 'autoc/collection'


module AutoC


  # Generator for singly linked collection of elements
  class List < Collection

    include Sequential

    def range = @range ||= Range.new(self, visibility: visibility)

    attr_reader :node

    def initialize(*args, **kws)
      super
      @node = identifier(:_N)
    end

    def render_interface(stream)
      stream << %{
        /**
          #{defgroup}

          @brief Singly linked list of elements of type #{element}

          For iteration over the list elements refer to @ref #{range}.

          @see C++ [std::forward_list<T>](https://en.cppreference.com/w/cpp/container/forward_list)

          @since 2.0
        */
        typedef struct #{signature} #{signature};
        typedef struct #{node} #{node}; /**< @private */
        /**
          #{ingroup}
          @brief Opaque structure holding state of the list
          @since 2.0
        */
        struct #{signature} {
          #{node}* front; /**< @private */
          size_t size; /**< @private */
        };
        /** @private */
        struct #{node} {
          #{element} element;
          #{node}* next;
        };
      }
    end

  private

    def configure
      super
      method(:void, :_drop_front, { target: rvalue }, visibility: :internal).configure do
        # Destroy front node but keep the element intact
        code %{
          #{node}* node;
          assert(!#{empty.(target)});
          node = target->front; assert(node);
          target->front = target->front->next;
          --target->size;
          #{memory.free(:node)};
        }
      end
      method(element.const_lvalue, :view_front, { target: const_rvalue }).configure do
        inline_code %{
          assert(!#{empty.(target)});
          return &(target->front->element);
        }
        header %{
          @brief Get a view of the front element

          @param[in] target list to get element from
          @return a view of a front element

          This function is used to get a constant reference (in form of the C pointer) to the front value contained in `target`.
          Refer to @ref #{take_front} to get an independent copy of that element.

          It is generally not safe to bypass the constness and to alter the value in place (although no one prevents to).

          @note List must not be empty (see @ref #{empty}).

          @since 2.0
        }
      end
      method(element, :pull_front, { target: rvalue }).configure do
        code %{
          #{element} result;
          assert(target);
          assert(!#{empty.(target)});
          result = *#{view_front.(target)};
          #{_drop_front.(target)};
          return result;
        }
        header %{
          @brief Extract front element

          @param[in] target list to extract element from
          @return front element

          This function removes front element from the list and returns it.
          Note that contrary to @ref #{take_front} no copy operation is performed - it is the contained value itself that is returned.

          @note List must not be empty (see @ref #{empty}).

          @since 2.0
        }
      end
      method(element, :take_front, { target: const_rvalue }, constraint:-> { element.copyable? }).configure do
        code %{
          #{element} result;
          #{element.const_lvalue} e;
          assert(target);
          assert(!#{empty.(target)});
          e = #{view_front.(target)};
          #{element.copy.(:result, '*e')};
          return result;
        }
        header %{
          @brief Get front element

          @param[in] target list to get element from
          @return a *copy* of a front element

          This function is used to get a *copy* of the front value contained in `self`.
          Refer to @ref #{view_front} to get a view of that element without making an independent copy.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @note List must not be empty (see @ref #{empty}).

          @since 2.0
        }
      end
      method(:void, :drop_front, { target: rvalue }).configure do
        if element.destructible?
          code %{
            #{element.lvalue} e;
            assert(target);
            assert(!#{empty.(target)});
            e = (#{element.lvalue})#{view_front.(target)};
            #{element.destroy.('*e')};
            #{_drop_front.(target)};
          }
        else
          code %{
            assert(target);
            assert(!#{empty.(target)});
            #{_drop_front.(target)};
          }
        end
        header %{
          @brief Drop front element

          @param[in] self list to drop element from

          This function removes front element from the list and destroys it with the respective destructor.

          @note List must not be empty (see @ref #{empty}).

          @since 2.0
        }
      end
      method(:void, :push_front, { target: rvalue, value: element.const_rvalue }, constraint:-> { element.copyable? }).configure do
        code %{
          #{node}* node;
          assert(target);
          node = #{memory.allocate(node)};
          #{element.copy.('node->element', value)};
          node->next = target->front;
          target->front = node;
          ++target->size;
        }
        header %{
          @brief Put element

          @param[in] target vector to put element into
          @param[in] value value to put

          This function pushes a *copy* of the specified value to the front position of `target`.
          It becomes a new front element.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @since 2.0
        }
      end
      method(:int, :remove, { self: rvalue, value: element.const_rvalue }, constraint:-> { element.comparable? }).configure do
        code %{
          #{node} *node, *prev_node;
          int removed = 0;
          assert(self);
          node = self->front;
          prev_node = NULL;
          while(node) {
            if(#{element.equal.('node->element', :value)}) {
              #{node}* this_node;
              if(prev_node) {
                this_node = prev_node->next = node->next;
              } else {
                this_node = self->front = node->next;
              }
              removed = 1;
              --self->size;
              #{element.destroy.('node->element') if element.destructible?};
              #{memory.free(:node)};
              node = this_node;
              if(removed) break;
            } else {
              prev_node = node;
              node = node->next;
            }
          }
          return removed;
        }
        header %{
          @brief Remove element

          @param[in] target list to remove element from
          @param[in] value value to search in list
          @return non-zero value on successful removal and zero value otherwise

          This function searches `self` for a first element equal to the specified `value` and removes it from the list.
          The removed element is destroyed with respective destructor.

          The function return value is non-zero if such element was found and removed and zero value otherwise.

          This function requires the element type to be *comparable* (i.e. to have a well-defined equality operation).

          @since 2.0
        }
      end
      default_create.configure do
        inline_code %{
          assert(target);
          target->front = NULL;
          target->size = 0;
        }
      end
      destroy.configure do
        code %{
          assert(target);
          while(!#{empty.(target)}) #{drop_front.(target)};
        }
      end
      copy.configure do
        code %{
          #{range} r;
          assert(target);
          assert(source);
          #{default_create.(target)};
          for(r = #{range.new.(source)}; !#{range.empty.(:r)}; #{range.pop_front.(:r)}) {
            #{element.const_lvalue} e = #{range.view_front.(:r)};
            #{push_front.(target, '*e')};
          }
          /* FIXME this code yields a reversed list TODO */
        }
      end
      empty.configure do
        inline_code %{
          assert(target);
          return target->front == NULL;
        }
      end
      size.configure do
        inline_code %{
          assert(target);
          return target->size;
        }
      end
    end
  end # List


  class List::Range < ForwardRange

    def render_interface(stream)
      stream << %{
        /**
          #{ingroup}
          @brief Opaque structure holding state of the list's range
          @since 2.0
        */
        typedef struct {
          #{iterable.node}* front; /**< @private */
        } #{signature};
      }
    end

  private

    def configure
      super
      custom_create.configure do
        inline_code %{
          assert(range);
          assert(iterable);
          range->front = iterable->front;
        }
      end
      empty.configure do
        inline_code %{
          assert(range);
          return range->front == NULL;
        }
      end
      pop_front.configure do
        inline_code %{
          assert(range);
          assert(!#{empty.(range)});
          range->front = range->front->next;
        }
      end
      view_front.configure do
        inline_code %{
          assert(range);
          assert(!#{empty.(range)});
          return &range->front->element;
        }
      end
    end

  end # List


end
