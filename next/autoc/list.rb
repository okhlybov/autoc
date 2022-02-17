# frozen_string_literal: true


require 'autoc/container'
require 'autoc/range'


module AutoC


  class List < Container

    include Container::Hashable

    def initialize(type, element, visibility = :public)
      super
      @node = decorate_identifier(:_node)
      @range = Range.new(self, visibility)
      dependencies << range
      [default_create, destroy, @size, @empty, @contains].each(&:inline!)
      @compare = nil # Don't know how to order the vectors
    end

    def canonic_tag = "List<#{element.type}>"

    def composite_interface_declarations(stream)
      stream << %$
        /**
          #{@defgroup} #{type} #{canonic_tag}
          @{

            @brief Singly linked list of elements of type #{element.type}

            For iteration over the list elements refer to @ref #{range.type}.

            @see C++ [std::forward_list<T>](https://en.cppreference.com/w/cpp/container/forward_list)

            @since 2.0
          */
        typedef struct #{@node} #{@node}; /**< @private */
        typedef struct #{type} #{type}; /**< @private */
        /**
          @brief Opaque structure holding state of the list
          @since 2.0
        */
        struct #{type} {
          #{@node}* head_node; /**< @private */
          size_t node_count; /**< @private */
        };
        /** @private */
        struct #{@node} {
          #{element.type} element;
          #{@node}* next_node;
        };
      $
      super
      stream << "/**@} #{type} */"
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
        /* ^ */
        #{define(default_create)} {
          assert(self);
          self->head_node = NULL;
          self->node_count = 0;
        }
        /** @private */
        #{declare} int #{_drop}(#{ptr_type} self);
        #{define(destroy)} {
          assert(self);
          while(#{_drop}(self));
        }
        /**
          @brief Remove and destroy all contained elements

          @param[in] self list to be purged

          The elements are destroyed with respective destructor.

          After call to this function the list will contain 0 elements.

          @since 2.0
         */
        #{define} void #{purge}(#{ptr_type} self) {
          #{destroy}(self);
          #{default_create}(self);
        }
        /* ^ */
        #{define(@size)} {
          assert(self);
          return self->node_count;
        }
        /* ^ */
        #{define(@empty)} {
          assert((self->node_count == 0) == (self->head_node == NULL));
          return #{size}(self) == 0;
        }
        /**
          @brief Get a view of the front element

          @param[in] self list to get element from
          @return a view of a front element

          This function is used to get a constant reference (in form of the C pointer) to the front value contained in `self`.
          Refer to @ref #{peek} to get an independent copy of that element.

          It is generally not safe to bypass the constness and to alter the value in place (although no one prevents to).

          @note List must not be empty (see @ref #{@empty}).

          @since 2.0
        */
        #{define} #{element.const_ptr_type} #{front_view}(#{const_ptr_type} self) {
          assert(self);
          return &(self->head_node->element);
        }
      $
      stream << %$
        /**
          @brief Get front element

          @param[in] self list to get element from
          @return a *copy* of a front element

          This function is used to get a *copy* of the front value contained in `self`.
          Refer to @ref #{view} to get a view of that element without making an independent copy.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @note List must not be empty (see @ref #{@empty}).

          @since 2.0
        */
        #{define} #{element.type} #{front}(#{const_ptr_type} self) {
          #{element.type} result;
          #{element.const_ptr_type} e;
          assert(!#{empty}(self));
          e = #{front_view}(self);
          #{element.copy(:result, '*e')};
          return result;
        }
        /**
          @brief Alias to @ref #{front}
          @since 2.0
        */
        #define #{peek}(self) #{front}(self)
        /**
          @brief Extract front element

          @param[in] self list to extract element from
          @return a *copy* of a front element

          This function is used to get a *copy* of the front value contained in `self` and removes original value from the list.
          The removed value is destroyed with respective destructor.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @note List must not be empty (see @ref #{@empty}).

          @since 2.0
        */
        #{define} #{element.type} #{pop_front}(#{ptr_type} self) {
          #{element.type} result;
          assert(!#{empty}(self));
          result = #{front}(self);
          #{_drop}(self);
          return result;
        }
        /**
          @brief Alias to @ref #{pop_front}
          @since 2.0
        */
        #define #{pop}(self) #{pop_front}(self)
        /**
          @brief Put element

          @param[in] self vector to put element into
          @param[in] value value to put

          This function pushes a *copy* of the specified value to `self`.
          It becomes a new front element.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @since 2.0
        */
        #{define} void #{push_front}(#{ptr_type} self, #{element.const_type} value) {
          #{@node}* new_node = #{memory.allocate(@node)};
          #{element.copy('new_node->element', :value)};
          new_node->next_node = self->head_node;
          self->head_node = new_node;
          ++self->node_count;
        }
        /**
          @brief Alias to @ref #{push_front}
          @since 2.0
        */
        #define #{push}(self, value) #{push_front}(self, value)
      $ if element.copyable?
      stream << %$
        /** @private */
        #{declare} #{element.const_ptr_type} #{_find_view}(#{const_ptr_type} self, #{element.const_type} value);
        /* ^ */
        #{define(@contains)} {
          return #{_find_view}(self, value) != NULL;
        }
        /**
          @brief Remove element

          @param[in] self list to remove element from
          @param[in] value value to search in list
          @return non-zero value on successful removal and zero value otherwise

          This function searches `self` for a first element equal to the specified `value` and removes it from the list.
          The removed element is destroyed with respective destructor.

          The function return value is non-zero if such element was found and removed and zero value otherwise.

          This function requires the element type to be *comparable* (i.e. to have a well-defined equality operation).

          @since 2.0
        */
        #{declare} int #{remove}(#{ptr_type} self, #{element.const_type} value);
      $ if element.comparable?
      stream << "/**@} #{type} */"
    end

    def definitions(stream)
      super
      stream << %$
        #{define} int #{_drop}(#{ptr_type} self) {
          if(!#{empty}(self)) {
            #{@node}* this_node = self->head_node; assert(this_node);
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
              #{element.const_ptr_type} a = #{range.front_view}(&ra);
              #{element.const_ptr_type} b = #{range.front_view}(&rb);
              if(!#{element.equal('*a', '*b')}) return 0;
            }
            return 1;
          } else return 0;
        }
      $ if comparable?
      stream << %$
        #{define} #{element.const_ptr_type} #{_find_view}(#{const_ptr_type} self, #{element.const_type} value) {
          for(#{range.type} r = #{get_range}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{element.const_ptr_type} e = #{range.front_view}(&r);
            if(#{element.equal('*e', :value)}) return e;
          }
          return NULL;
        }
        #{define} int #{remove}(#{ptr_type} self, #{element.const_type} value) {
          #{@node} *node, *prev_node;
          int removed = 0;
          assert(self);
          node = self->head_node;
          prev_node = NULL;
          while(node) {
            if(#{element.equal('node->element', :value)}) {
              #{@node}* this_node;
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
        @list_node = iterable.instance_variable_get(:@node)
        [custom_create, @empty, @save, @pop_front, @front_view, @front].each(&:inline!)
      end

      def composite_interface_declarations(stream)
        stream << %$
          /**
            #{@defgroup} #{type} #{canonic_tag}
            @ingroup #{iterable.type}
            @{

              @brief #{canonic_desc}

              This range implements the @ref #{archetype} archetype.

              @see @ref Range

              @since 2.0
          */
          /**
            @brief Opaque structure holding state of the list's range
            @since 2.0
          */
          typedef struct {
            #{@list_node}* node; /**< @private */
          } #{type};
        $
        super
        stream << "/**@} #{type} */"
      end

      def composite_interface_definitions(stream)
        stream << %$
          /**
            #{@addtogroup} #{type}
            @{
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
        stream << "/**@} #{type} */"
      end

    end


  end


end