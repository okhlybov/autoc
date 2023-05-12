# frozen_string_literal: true


require 'autoc/std'
require 'autoc/set'
require 'autoc/list'
require 'autoc/vector'
require 'autoc/randoms'


module AutoC


  using STD::Coercions


  class HashSet < Set

    def _slot_class = List

    def _bin_class = Vector

    def range = @range ||= Range.new(self, visibility: visibility)

    def _slot = @_slot ||= _slot_class.new(identifier(:_list, abbreviate: true), element, _master: self, maintain_size: false, visibility: :internal)

    def _bin = @_bin ||= _bin_class.new(identifier(:_vector, abbreviate: true), _slot, _master: self, visibility: :internal)

    def initialize(*args, **kws)
      super
      dependencies << _bin << Seed.instance
    end

    def render_interface(stream)
      if public?
        stream << %{
          /**
            #{defgroup}

            @brief Unordered collection of unique elements of type #{element}

            For iteration over the set elements refer to @ref #{range}.

            @see C++ [std::unordered_set<T>](https://en.cppreference.com/w/cpp/container/unordered_set)

            @since 2.0
          */
          /**
            #{ingroup}
            @brief Opaque structure holding state of the hash set
            @since 2.0
          */
        }
      else
        stream << PRIVATE
      end
      stream << %{
        typedef struct {
          #{_bin} bin; /**< @private */
          size_t size; /**< @private */
          size_t hash_mask; /**< @private */
        } #{signature};
      }
    end

  private

    def configure
      super
      method(:void, :create_capacity, { target: lvalue, capacity: :size_t.rvalue }).configure do
        code %{
          unsigned char bits = 0;
          assert(target);
          target->size = 0;
          /* fix capacity to become the ceiling to the nearest power of two */
          if(capacity % 2 == 0) --capacity;
          while(capacity >>= 1) ++bits;
          capacity = (size_t)1 << (bits+1); assert(capacity > 0);
          target->hash_mask = capacity-1; /* fast slot location for value: hash_code(value) & hash_mask */
          #{_bin.custom_create.('target->bin', capacity)};
          assert(#{_bin.size.('target->bin')} % 2 == 0);
        }
        header %{
          @brief Create set with specified capacity

          @param[out] target set to create
          @param[in] capacity initial capacity of the set

          This function creates a new set which should be suffice to contain specific number of elements.

          While the input capacity may be arbitrary the resulting one will be rounded up to the nearest power of two.

          This function may be useful when the (approximate) number of elements this set is about to contain is known in advance
          in order to avoid expensive storage reallocation & elements rehashing operations during the set's lifetime.

          @since 2.0
        }
      end
      def _find_slot_hash(hash)
        %{
          assert(target);
          return #{_bin.view.('target->bin', "#{hash} & target->hash_mask")};
        }
      end
      method(_slot.const_lvalue, :_find_slot, { target: const_rvalue, value: element.const_rvalue }, visibility: :internal).configure do
        # Find slot based on the value hash code
        dependencies << _bin.view
        inline_code _find_slot_hash(element.hash_code.(value))
      end
      method(:void, :_expand, { target: lvalue, force: :int.const_rvalue }, visibility: :internal).configure do
        code %{
          #{type} set;
          #{_bin.range} r;
          assert(target);
          /* capacity threshold == 1.0 */
          if(force || target->size >= #{_bin.size.('target->bin')}) {
            #{create_capacity.(:set, _bin.size.('target->bin') + '*2')};
            /* move elements to newly allocated set */
            for(r = #{_bin.range.new.('target->bin')}; !#{_bin.range.empty.(:r)}; #{_bin.range.pop_front.(:r)}) {
              #{_slot.lvalue} src = (#{_slot.lvalue})#{_bin.range.view_front.(:r)};
              while(!#{_slot.empty.('*src')}) {
                /* direct node relocation from original to new list bypassing node reallocation & payload copying */
                #{_slot._node_p} node = #{_slot._pull_node.('*src')};
                #{_slot.lvalue} dst = (#{_slot.lvalue})#{_find_slot.(target, 'node->element')};
                #{_slot._push_node.('*dst', '*node')};
              }
            }
            set.size = target->size; /* assume all elements have been moved into new set */
            #{destroy.(target)};
            *target = set;
          }
        }
      end
      subset.configure do
        code %{
          #{range} r;
          assert(target);
          assert(other);
          if(#{size.(target)} > #{size.(other)}) return 0; /* larger set can't be a subset of a smaller one */
          for(r = #{range.new.(target)}; !#{range.empty.(:r)}; #{range.pop_front.(:r)}) {
            #{element.const_lvalue} e = #{range.view_front.(:r)};
            if(!#{contains.(other, '*e')}) return 0;
          }
          return 1;
        }
      end
      remove.configure do
        code %{
          int c;
          #{_slot.lvalue} s;
          assert(target);
          s = (#{_slot.lvalue})#{_find_slot.(target, value)};
          c = #{_slot.remove_first.('*s', value)};
          if(c) --target->size;
          return c;
        }
      end
      put.configure do
        code %{
          #{_slot.lvalue} s;
          assert(target);
          s = (#{_slot.lvalue})#{_find_slot.(target, value)};
          if(!#{_slot.find_first.('*s', value)}) {
            #{_expand.(target, 0)};
            #{_slot.push_front.('*s', value)};
            ++target->size;
            return 1;
          } else return 0;
        }
      end
      push.configure do
        code %{
          #{_slot.lvalue} s;
          assert(target);
          s = (#{_slot.lvalue})#{_find_slot.(target, value)};
          if(#{_slot._replace_first.('*s', value)}) {
            return 1;
          } else {
            /* add brand new value */
            #{_expand.(target, 0)};
            #{_slot.push_front.('*s', value)};
            ++target->size;
            return 0;
          }
        }
      end
      default_create.configure do
        dependencies << create_capacity
        inline_code %{
          #{create_capacity.(target, 8)};
        }
      end
      find_first.configure do
        code %{
          #{_slot.const_lvalue} s = #{_find_slot.(target, value)};
          return #{_slot.find_first.('*s', value)};
        }
      end
      copy.configure do
        code %{
          assert(target);
          assert(source);
          #{_bin.copy.('target->bin', 'source->bin')};
          target->hash_mask = source->hash_mask;
          target->size = source->size;
        }
      end
      empty.configure do
        inline_code %{
          assert(target);
          return target->size == 0;
        }
      end
      size.configure do
        inline_code %{
          assert(target);
          return target->size;
        }
      end
      contains.configure do
        code %{
          #{_slot.const_lvalue} s;
          assert(target);
          s = #{_find_slot.(target, value)};
          return #{_slot.contains.('*s', value)};
        }
      end
      destroy.configure do
        code %{
          assert(target);
          #{_bin.destroy.('target->bin')};
        }
      end
      hash_code.configure do
        code %{
          #{range} r;
          size_t hash; /* default incremental hasher is applicable to ordered collections only */
          for(hash = AUTOC_SEED, r = #{range.new.(target)}; !#{range.empty.(:r)}; #{range.pop_front.(:r)}) {
            #{element.const_lvalue} e = #{range.view_front.(:r)};
            hash ^= #{element.hash_code.('*e')};
          }
          return hash;
        }
      end
    end

  end # HashSet


  class HashSet::Range < ForwardRange

    def render_interface(stream)
      if public?
        render_type_description(stream)
        stream << %{
          /**
            #{ingroup}
            @brief Opaque structure holding state of the hash set's range
            @since 2.0
          */
        }
      else
        stream << PRIVATE
      end
      stream << %{
        typedef struct {
          #{_bin} bin; /**< @private */
          #{_slot} slot; /**< @private */
        } #{signature};
      }
    end

    def _slot = iterable._slot.range

    def _bin = iterable._bin.range

  private

    def configure
      super
      method(:void, :_advance, { range: rvalue }, visibility: :internal ).configure do
        code %{
          assert(range);
          while(1) {
            if(#{_slot.empty.('range->slot')}) {
              /* current slot's range is empty - iterate forward to the next one */
              #{_bin.pop_front.('range->bin')};
              if(#{_bin.empty.('range->bin')}) {
                /* all bin are iterated through, slot range is also empty - end of set */
                break;
              } else {
                /* advance to the new (possibly empty) slot */
                #{iterable._slot.const_lvalue} b = #{_bin.view_front.('range->bin')};
                range->slot = #{_slot.new.('*b')};
              }
            } else {
              /* current slot's range is not empty - no need to proceed */
              break;
            }
          }
        }
      end
      custom_create.configure do
        code %{
          #{_iterable._slot.const_lvalue} s;
          assert(range);
          assert(iterable);
          range->bin = #{_bin.new.('iterable->bin')};
          /* get the first slot's range regardless of its emptiness status */
          s = #{_bin.view_front.('range->bin')};
          range->slot = #{_slot.new.('*s')};
          /* actually advance to the first non-empty slot */
          #{_advance.(range)};
        }
      end
      empty.configure do
        code %{
          assert(range);
          return #{_slot.empty.('range->slot')};
        }
      end
      pop_front.configure do
        code %{
          assert(range);
          #{_slot.pop_front.('range->slot')};
          #{_advance.(range)};
        }
      end
      view_front.configure do
        code %{
          assert(range);
          assert(!#{empty.(range)});
          return #{_slot.view_front.('range->slot')};
        }
      end
    end

  end # Range


end