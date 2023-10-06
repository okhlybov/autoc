# frozen_string_literal: true


require 'autoc/std'
require 'autoc/association'


module AutoC


  using STD::Coercions


  # @abstract
  class IntrusiveHashMap < Association

    def orderable? = false

    def range = @range ||= Range.new(self, visibility: visibility)

    attr_reader :load_factor

    attr_reader :_slot, :_slot_p

    def initialize(*args, load_factor: 0.75, auxillaries: false, **kws)
      super(*args, **kws)
      @_slot = identifier(:_slot, abbreviate: true)
      @_slot_p = _slot.lvalue
      @load_factor = load_factor
      @auxillaries = auxillaries
    end

    def render_interface(stream)
      stream << %{
        /** @private */
        typedef struct {
          #{element} element;
          #{index} index;
        } #{_slot};
      }
      if public?
        stream << %{
          /**
            #{defgroup}

            @brief Unordered collection of elements of type #{element} associated with unique index of type #{index}

            This implementation employs open hashing technique.

            For iteration over the set elements refer to @ref #{range}.

            @see C++ [std::unordered_map<T>](https://en.cppreference.com/w/cpp/container/unordered_map)

            @since 2.1
          */
          /**
            #{ingroup}
            @brief Opaque structure holding state of the hash map
            @since 2.1
          */
        }
      else
        stream << PRIVATE
      end
      stream << %{
        typedef struct {
          #{_slot_p} slots; /**< @private */
          size_t size; /**< @private */
          size_t capacity; /**< @private */
        } #{signature};
      }
    end

    def render_forward_declarations(stream)
      stream << %{
        #define #{_EMPTY} 1
        #define #{_DELETED} 2
      }
      super
    end

    def _EMPTY = identifier(:_EMPTY)
    def _DELETED = identifier(:_DELETED)

    def _element = element
    def _index = index

  private

    def configure
      super
      method(:void, :mark, { slot: _slot_p, state: :int }, visibility: :internal)
      method(:int, :marked, { slot: _slot_p }, visibility: :internal)
      method(:void, :create_capacity, { target: lvalue, capacity: :size_t.rvalue }).configure do
        code %{
          size_t slot;
          unsigned char bits = 0;
          assert(target);
          /* fix capacity to become the ceiling to the nearest power of two */
          if(capacity % 2 == 0) --capacity;
          while(capacity >>= 1) ++bits;
          capacity = (size_t)1 << (bits+1); assert(capacity > 0);
          target->size = 0;
          target->capacity = capacity; /* fast slot location for value: hash_code(value) & (capacity-1) */
          target->slots = (#{_slot_p})#{memory.allocate(_slot, :capacity)}; assert(target->slots);
          for(slot = 0; slot < target->capacity; ++slot) #{mark}(target->slots + slot, #{_EMPTY});
        }
        header %{
          @brief Create set with specified capacity

          @param[out] target set to create
          @param[in] capacity initial capacity of the set

          This function creates a new set which should be suffice to contain specific number of elements.

          While the input capacity may be arbitrary the resulting one will be rounded up to the nearest power of two.

          This function may be useful when the (approximate) number of elements this set is about to contain is known in advance
          in order to avoid expensive storage reallocation & elements rehashing operations during the set's lifetime.

          @since 2.1
        }
      end
      method(:size_t, :first_slot, { target: const_rvalue, slot: _slot_p }, visibility: :internal).configure do
        inline_code %{
          assert(target);
          return #{_index.hash_code.('slot->index')} & (target->capacity-1);
        }
      end
      method(:size_t, :next_slot, { target: const_rvalue, slot: :size_t}, visibility: :internal).configure do
        inline_code %{
          assert(target);
          return (slot+1) & (target->capacity-1); /* linear probing */
        }
      end
      method(_slot_p, :_lookup, { target: const_rvalue, index: index.const_rvalue }, visibility: :private).configure do
        code %{
          int state;
          size_t slot;
          #{_slot_p} next_slot;
          #{_slot} the_slot;
          assert(target);
          the_slot.index = #{index.to_value_argument}; /* skipping .element since it is not used in the lookup process */
          slot = #{first_slot}(target, &the_slot);
          /* zero state signifies real value, deleted state means slot gets skipped, empty state means end of search */
          while((state = #{marked}(next_slot = target->slots + slot)) != #{_EMPTY}) {
            if(!state && #{_index.equal.('next_slot->index', index)}) return next_slot;
            slot = #{next_slot}(target, slot);
          }
          return NULL;
        }
      end
      method(:void, :adopt_slot, { target: rvalue, new_slot: _slot_p }, visibility: :internal).configure do
        code %{
          size_t slot;
          #{_slot_p} next_slot;
          assert(target);
          assert(target->size <= target->capacity);
          slot = #{first_slot.(target, new_slot)};
          /* looking for the first slot that is marked either empty or deleted */
          while(!#{marked}(next_slot = target->slots + slot)) slot = #{next_slot}(target, slot);
          *next_slot = *new_slot;
        }
      end
      method(:void, :_expand, { target: lvalue, force: :int.const_rvalue }, visibility: :private).configure do
        code %{
          assert(target);
          assert(target->capacity*#{load_factor} <= target->capacity); /* guarding againt accidental shrinking */
          if(force || target->size > target->capacity*#{load_factor}) {
            size_t slot;
            size_t source_capacity = target->capacity, source_size = target->size;
            #{_slot_p} source_slots = target->slots;
            #{create_capacity}(target, source_capacity << 1);
            for(slot = 0; slot < source_capacity; ++slot) {
              #{_slot_p} next_slot = source_slots + slot;
              if(!#{marked}(next_slot)) #{adopt_slot.(target, '*next_slot')};
            }
            target->size = source_size; /* restore the size since create_capacity() resets it to zero */
            #{memory.free(:source_slots)};
          }
        }
      end
      method(:void, :put_force, { target: rvalue, element: element.const_rvalue, index: index.const_rvalue }, visibility: :internal).configure do
        code %{
          #{_slot} slot;
          assert(target);
          /* make copies right away since adopt() won't do this by itself */
          #{_element.copy.('slot.element', element)};
          #{_index.copy.('slot.index', index)};
          #{adopt_slot.(target, :slot)};
          ++target->size;
          #{_expand}(target, 0);
        }
      end
      set.configure do
        code %{
          #ifndef NDEBUG
            #{_slot} the_slot;
          #endif
          assert(target);
          #ifndef NDEBUG
            the_slot.element = #{value.to_value_argument};
            the_slot.index = #{index.to_value_argument};
            assert(!#{marked.(:the_slot)}); /* ensure the values to be inserted do not contain marked values */
          #endif
          if(!#{_lookup}(target, index)) #{put_force}(target, value, index);
        }
      end
      method(:int, :remove, { target: rvalue, index: index.const_rvalue }).configure do
        code %{
          #{_slot_p} slot;
          assert(target);
          if(slot = #{_lookup}(target, index)) {
            #{_element.destroy.('slot->element') if _element.destructible?};
            #{_index.destroy.('slot->index') if _index.destructible?};
            #{mark}(slot, #{_DELETED});
            --target->size;
            return 1;
          } else return 0;
        }
      end
      equal.configure do
        code %{
          assert(left);
          assert(right);
          if(#{size}(left) == #{size}(right)) {
            #{range} lt, rt;
            for(lt = #{range.new}(left), rt = #{range.new}(right); !#{range.empty}(&lt) && !#{range.empty}(&rt); #{range.pop_front}(&lt), #{range.pop_front}(&rt)) {
              #{index.const_lvalue} li = #{range.view_index_front}(&lt);
              #{index.const_lvalue} ri = #{range.view_index_front}(&rt);
              #{element.const_lvalue} le = #{range.view_front}(&lt);
              #{element.const_lvalue} re = #{range.view_front}(&rt);
              if(!#{index.equal.('*li', '*ri')} || !#{element.equal.('*le', '*re')}) return 0;
            }
            return 1;
          } else return 0;
        }
      end
      default_create.configure do
        dependencies << create_capacity
        inline_code %{
          #{create_capacity.(target, 8)};
        }
      end
      check.configure do
        dependencies << _lookup
        inline_code %{
          assert(target);
          return #{_lookup}(target, index) != NULL;
        }
      end
      find_first.configure do
        code %{
          #{range} r;
          assert(target);
          for(r = #{range.new}(target); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{element.const_lvalue} e = #{range.view_front.(:r)};
            if(#{element.equal.(value, '*e')}) return e;
          }
          return NULL;
        }
      end
      copy.configure do
        code %{
          #{range} r;
          assert(target);
          assert(source);
          #{create_capacity}(target, source->capacity);
          for(r = #{range.new}(source); !#{range.empty}(&r); #{range.pop_front}(&r)) #{set}(target, *#{range.view_index_front}(&r), *#{range.view_front}(&r));
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
        dependencies << _lookup
        inline_code %{
          assert(target);
          return #{find_first}(target, value) != NULL;
        }
      end
      view.configure do
        dependencies << _lookup
        inline_code %{
          #{_slot_p} slot;
          assert(target);
          return (slot = #{_lookup}(target, index)) ? &slot->element : NULL;
        }
      end
      destroy_slots_code = %{
        {
          #{range} r;
          for(r = #{range.new}(target); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{element.lvalue} e;
            #{index.lvalue} i;
            e = (#{element.lvalue})#{range.view_front}(&r);
            i = (#{index.lvalue})#{range.view_index_front}(&r);
            #{element.destroy.('*e') if element.destructible?};
            #{index.destroy.('*i') if index.destructible?};
          }
        }
      } if element.destructible? || index.destructible?
      destroy.configure do
        code %{
          assert(target);
          #{destroy_slots_code}
          #{memory.free('target->slots')};
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
      # Return number of equality test operations performed to find element or -1 on failure
      # NOTE this method must stay in sync with #lookup
      method(:int, :count_eops, { target: const_rvalue, index: index.const_rvalue}, constraint:-> { @auxillaries }, visibility: :internal).configure do
        code %{
          int state, ops = 1;
          size_t slot;
          #{_slot_p} next_slot;
          #{_slot} the_slot;
          assert(target);
          the_slot.index = #{index.to_value_argument}; /* skipping .element since it is not used in the lookup process */
          slot = #{first_slot}(target, the_slot);
          /* zero state signifies real value, deleted state means slot gets skipped, empty state means end of search */
          while((state = #{marked}(next_slot = target->slots + slot)) != #{_EMPTY}) {
            if(!state && #{_index.equal.('next_slot->index', index)}) return ops;
            slot = #{next_slot}(target, slot);
            ++ops;
          }
          return -1;
        }
      end
      method(:void, :print_stats, { target: const_rvalue, stream: 'FILE*' }, constraint:-> { @auxillaries }, visibility: :private).configure do
        dependencies << AutoC::STD::STDIO_H
        code %{
          int eops = 0, max_eops = 0;
          #{range} r;
          assert(target);
          assert(stream);
          fprintf(stream, "#{type}<#{element}> (#{type.class}<#{element.class}>) @%p\\n", target);
          fprintf(stream, "\\tsize = %zd elements\\n", target->size);
          fprintf(stream, "\\tcapacity = %zd slots\\n", target->capacity);
          fprintf(stream, "\\tslots utilization = %.02f%%\\n", 100.0*target->size/target->capacity);
          fprintf(stream, "\\tbuilt in load factor = #{load_factor}\\n");
          for(r = #{range.new}(target); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            int e = #{count_eops}(target, *#{range.view_front}(&r)); assert(e >= 0);
            if(max_eops < e) max_eops = e;
            eops += e;
          }
          fprintf(stream, "\\taverage lookup complexity = %.02f equality tests\\n", (double)eops/target->size);
          fprintf(stream, "\\tmaximum lookup complexity = %d equality tests\\n", max_eops);
        }
      end
    end

  end # IntrusiveHashSet

 
  class IntrusiveHashMap::Range < AssociativeRange

    def render_interface(stream)
      if public?
        render_type_description(stream)
        stream << %{
          /**
            #{ingroup}
            @brief Opaque structure holding state of the hash map's range
            @since 2.1
          */
        }
      else
        stream << PRIVATE
      end
      stream << %{
        typedef struct {
          #{iterable._slot_p} slots; /**< @private */
          size_t capacity; /**< @private */
          ptrdiff_t slot; /**< @private */
        } #{signature};
      }
    end

  private

    def configure
      super
      custom_create.configure do
        code %{
          assert(range);
          assert(iterable);
          range->slots = iterable->slots;
          range->capacity = iterable->capacity;
          range->slot = -1;
          #{pop_front}(range);
        }
      end
      empty.configure do
        code %{
          assert(range);
          return range->slot >= range->capacity;
        }
      end
      pop_front.configure do
        code %{
          do ++range->slot; while(!#{empty}(range) && #{iterable.marked}(range->slots + range->slot));
        }
      end
      view_front.configure do
        dependencies << empty
        code %{
          assert(!#{empty}(range));
          return &(range->slots + range->slot)->element;
        }
      end
      view_index_front.configure do
        dependencies << empty
        code %{
          assert(!#{empty}(range));
          return &(range->slots + range->slot)->index;
        }
      end
    end

  end # Range


end