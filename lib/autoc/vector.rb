# frozen_string_literal: true


require 'autoc/ranges'
require 'autoc/containers'


module AutoC


  using STD::Coercions


  class Vector < ContiguousContainer

    def hashable? = false # TODO

    def range = @range ||= Range.new(self, visibility: visibility, parallel: @parallel)

    def render_interface(stream)
      stream << %{
        /**
          #{defgroup}

          @brief Resizable vector of elements of type #{element}

          #{type} is a container that encapsulates dynamic size array of values of type #{element}.

          It is a contiguous sequence direct access container where elements can be directly referenced by an integer index belonging to the [0, @ref #{size}) range.

          For iteration over the vector elements refer to @ref #{range}.

          @see C++ [std::vector<T>](https://en.cppreference.com/w/cpp/container/vector)

          @since 2.0
        */
        /**
          #{ingroup}

          @brief Opaque structure holding state of the vector
          @since 2.0
        */
        typedef struct {
          #{element.lvalue} elements; /**< @private */
          size_t size; /**< @private */
        } #{signature};
      }

    end

    def render_implementation(stream)
      stream << %{
        #include <malloc.h>
        #include <string.h>
      }
      if element.comparable?
        stream << %{
          #include <stdlib.h>
          static int #{ascend}(const void* left, const void* right) {
            return #{element.compare.("(*(#{element.lvalue})left)", "(*(#{element.lvalue})right)")};
          }
          static int #{descend}(const void* left, const void* right) {
            return -#{ascend}(left, right);
          }
          #{sort.prototype} {
            qsort(#{storage(:target)}, #{size.('*target')}, sizeof(#{element}), ascending ? #{ascend} : #{descend});
          }
        }
      end
      super
    end

    def storage(target) = "(#{target})->elements" # Return C pointer to contiguous storage

  private

    def configure
      super
      method(:void, :_allocate, { target: lvalue, size: :size_t.const_rvalue }, visibility: :internal).configure do
        code %{
          if((target->size = size) > 0) {
            #{storage(:target)} = (#{element.lvalue})malloc(size*sizeof(#{element})); assert(#{storage(:target)});
          } else {
            #{storage(:target)} = NULL;
          }
        }
      end
      method(:void, :create_size, { target: lvalue, size: :size_t.const_rvalue }, instance: :custom_create, constraint:-> { custom_constructible? && element.default_constructible? }).configure do
        code %{
          size_t index;
          assert(target);
          #{_allocate.(target, size)};
          for(index = 0; index < size; ++index) {
            #{element.default_create.("#{storage(:target)}[index]")};
          }
        }
        header %{
          @brief Create a new vector of specified size

          @param[out] target vector to be initialized
          @param[in] size size of new vector

          Each new vector's element is initialized with the respective default constructor.

          This function requires the element type to be *default constructible* (i.e. to have a well-defined parameterless constructor).

          @note Previous contents of `*target` is overwritten.

          @since 2.0
        }
      end
      method(:void, :create_set, { target: lvalue, size: :size_t.const_rvalue, initializer: element.const_rvalue }, constraint:-> { element.copyable? }).configure do
        code %{
          size_t index;
          assert(target);
          #{_allocate.(target, size)};
          for(index = 0; index < size; ++index) {
            #{element.copy.("#{storage(:target)}[index]", initializer)};
          }
        }
        header %{
          @brief Create and initialize a new vector of specified size

          @param[out] target vector to be initialized
          @param[in] size size of new vector
          @param[in] initializer value to initialize the vector with

          Each new vector's element is set to a *copy* of the specified value.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @note Previous contents of `*target` is overwritten.

          @since 2.0
        }
      end
      destroy_elements = "for(index = common_size; index < old_size; ++index) {#{element.destroy.('old_elements[index]')};}" if element.destructible?
      method(:void, :resize, { target: lvalue, new_size: :size_t.const_rvalue }, constraint:-> { element.default_constructible? }).configure do
        code %{
          size_t old_size;
          assert(target);
          if((old_size = #{size.(target)}) != new_size) {
            size_t common_size, index;
            #{element.lvalue} new_elements;
            #{element.lvalue} old_elements;
            old_elements = #{storage(:target)};
            #{_allocate.(target, new_size)};
            new_elements = #{storage(:target)};
            common_size = old_size < new_size ? old_size : new_size; /* min(old_size, new_size) */
            if(common_size > 0) {
              memcpy(new_elements, old_elements, common_size*sizeof(#{element}));
            }
            for(index = common_size; index < new_size; ++index) {
              #{element.default_create.('new_elements[index]')};
            }
            #{destroy_elements}
            free(old_elements);
          }
        }
      end
      default_create.configure do
        inline_code %{
          assert(target);
          #{storage(:target)} = NULL;
          target->size = 0;
        }
      end
      destroy_elements = "for(index = 0; index < #{size}(target); ++index) {#{element.destroy.("#{storage(:target)}[index]")};}" if element.destructible?
      destroy.configure do
        code %{
          size_t index;
          assert(target);
          #{destroy_elements}
          free(#{storage(:target)});
        }
      end
      copy.configure do
        code %{
          size_t index, size;
          assert(target);
          assert(source);
          size = #{size.(source)};
          #{_allocate.(target, :size)};
          for(index = 0; index < size; ++index) {
            #{element.copy.("#{storage(:target)}[index]", "#{storage(:source)}[index]")};
          }
        }
      end
      equal.configure do
        code %{
          size_t size;
          assert(left);
          assert(right);
          size = #{size.(left)};
          if(size == #{size.(right)}) {
            size_t index;
            for(index = 0; index < size; ++index) {
              if(!#{element.equal.("#{storage(:left)}[index]", "#{storage(:right)}[index]")}) return 0;
            }
            return 1;
          } else {
            return 0;
          }
        }
      end
      compare.configure do
        code %{
          size_t index, min_size, ls, rs;
          assert(left);
          assert(right);
          ls = #{size.(left)}; 
          rs = #{size.(right)};
          min_size = ls < rs ? ls : rs; /* min(ls, rs) */
          for(index = 0; index < min_size; ++index) {
            int c = #{element.compare.("#{storage(:left)}[index]", "#{storage(:right)}[index]")};
            if(c != 0) return c; /* early exit on first non-equal pair encountered */
          }
          if(ls == rs) {
            return 0; /* both vectors are completely equal */
          } else {
            return ls > rs ? +1 : -1; /* the longer vector of the two with equal common part is considered "the more" */
          }
        }
      end
      contains.configure do
        code %{
          size_t index, size;
          assert(target);
          size = #{size.(target)};
          for(index = 0; index < size; ++index) {
            if(#{element.equal.("#{storage(:target)}[index]", value)}) return 1;
          }
          return 0;
        }
      end
      size.configure do
        inline_code %{
          assert(target);
          return target->size;
        }
      end
      check.configure do
        dependencies << size
        inline_code %{
          assert(target);
          return index < #{size.(target)};
        }
      end
      empty.configure do
        dependencies << size
        inline_code %{
          assert(target);
          return !#{size.(target)};
        }
      end
      view.configure do
        dependencies << check
        inline_code %{
          assert(target);
          assert(#{check.(target, index)});
          return &#{storage(:target)}[index];
        }
      end
      set.configure do
        dependencies << check << view
        inline_code %{
          #{element.lvalue} e;
          assert(target);
          assert(#{check.(target, index)});
          e = (#{element.lvalue})#{view.(target, index)};
          #{element.copy.('*e', value)};
        }
      end
      method(:void, :sort, { target: rvalue, ascending: :int.const_rvalue }, constraint:-> { element.orderable? }, abstract: true).configure do
      end
    end

  end # Vector


  Vector::Range = ContiguousRange # Range


end