# frozen_string_literal: true


require 'autoc/std'
require 'autoc/set'
require 'autoc/ranges'


module AutoC


  using STD::Coercions


  # @abstract
  class IntrusiveHashSet < Set

    def range = @range ||= Range.new(self, visibility: visibility)

    attr_reader :load_factor

    attr_reader :_slot, :_slot_p

    def initialize(*args, load_factor: 0.75, auxillaries: false, **kws)
      super(*args, **kws)
      @_slot = decorate(:_slot, abbreviate: true)
      @_slot_p = _slot.lvalue
      @load_factor = load_factor
      @auxillaries = auxillaries
    end

    def render_interface(stream)
      stream << %{
        /** @private */
        typedef struct {
          #{element} element;
        } #{_slot};
      }
      if public?
        stream << %{
          /**
            #{defgroup}

            @brief Unordered collection of unique elements of type #{element}

            This implementation employs open hashing technique.

            For iteration over the set elements refer to @ref #{range}.

            @see C++ [std::unordered_set<T>](https://en.cppreference.com/w/cpp/container/unordered_set)

            @since 2.1
          */
          /**
            #{ingroup}
            @brief Opaque structure holding state of the hash set
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

    def _element = element

  private

    def configure
      super
      method(:void, :tag_empty, { slot: _slot_p }, visibility: :internal)
      method(:int, :is_empty, { slot: _slot_p }, visibility: :internal)
      method(:void, :tag_deleted, { slot: _slot_p }, visibility: :internal)
      method(:int, :is_deleted, { slot: _slot_p }, visibility: :internal)
      method(:int, :tagged, { slot: _slot_p }, visibility: :internal).inline_code %{return #{is_empty}(slot) || #{is_deleted}(slot);}
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
          for(slot = 0; slot < target->capacity; ++slot) #{tag_empty}(target->slots + slot);
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
          return #{_element.hash_code.('slot->element')} & (target->capacity-1);
        }
      end
      method(:size_t, :next_slot, { target: const_rvalue, slot: :size_t}, visibility: :internal).configure do
        inline_code %{
          assert(target);
          return (slot+1) & (target->capacity-1); /* linear probing */
        }
      end
      method(_slot_p, :_lookup, { target: const_rvalue, value: element.const_rvalue }, visibility: :private).configure do
        code %{
          size_t slot;
          #{_slot_p} next_slot;
          #{_slot} slot_ = { #{value.to_value_argument} };
          assert(target);
          slot = #{first_slot.(target, :slot_)};
          /* zero state signifies real value, deleted state means slot gets skipped, empty state means end of search */
          while(!#{is_empty}(next_slot = target->slots + slot)) {
            if(!#{is_deleted}(next_slot) && #{element.equal.('next_slot->element', value)}) return next_slot;
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
          while(!#{tagged}(next_slot = target->slots + slot)) slot = #{next_slot}(target, slot);
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
              if(!#{tagged}(next_slot)) #{adopt_slot.(target, '*next_slot')};
            }
            target->size = source_size; /* restore the size since create_capacity() resets it to zero */
            #{memory.free(:source_slots)};
          }
        }
      end
      method(:void, :put_force, { target: rvalue, value: element.const_rvalue }, visibility: :internal).configure do
        code %{
          #{_slot} slot;
          assert(target);
          #{element.copy.('slot.element', value)}; /* make a copy right away since adopt() won't do this by itself */
          #{adopt_slot.(target, :slot)};
          ++target->size;
          #{_expand}(target, 0);
        }
      end
      put.configure do
        code %{
          #ifndef NDEBUG
            #{_slot} slot_ = { #{value.to_value_argument} };
          #endif
          assert(target);
          assert(!#{tagged}(&slot_));
          if(!#{_lookup}(target, value)) {
            #{put_force}(target, value);
            return 1;
          } else return 0;
        }
      end
      push.configure do
        code %{
          #{_slot_p} slot;
          #ifndef NDEBUG
            #{_slot} slot_ = { #{value.to_value_argument} };
          #endif
          assert(target);
          assert(!#{tagged}(&slot_));
          if(slot = #{_lookup}(target, value)) {
            #{element.destroy.('slot->element') if element.destructible?};
            #{element.copy.('slot->element', value)};
            return 1;
          } else {
            #{put_force}(target, value);
            return 0;
          }
        }
      end
      remove.configure do
        code %{
          #{_slot_p} slot;
          assert(target);
          if(slot = #{_lookup}(target, value)) {
            #{element.destroy.('slot->element') if element.destructible?};
            #{tag_deleted}(slot);
            --target->size;
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
      find_first.configure do
        code %{
          #{_slot_p} slot = #{_lookup}(target, value);
          return slot ? &slot->element : NULL;
        }
      end
      copy.configure do
        code %{
          #{range} r;
          assert(target);
          assert(source);
          #{create_capacity}(target, source->capacity);
          for(r = #{range.new}(source); !#{range.empty}(&r); #{range.pop_front}(&r)) #{put}(target, *#{range.view_front}(&r));
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
          assert(target);
          return #{find_first}(target, value) != NULL;
        }
      end
      destroy_slots_code = %{
        {
          #{range} r;
          for(r = #{range.new}(target); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{element.lvalue} e = (#{element.lvalue})#{range.view_front}(&r);
            #{element.destroy.('*e')};
          }
        }
      } if element.destructible?
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
          for(hash = AUTOC_SEED, r = #{range.new}(target); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{element.const_lvalue} e = #{range.view_front.(:r)};
            hash ^= #{element.hash_code.('*e')};
          }
          return hash;
        }
      end
      # Return number of equality test operations performed to find element or -1 on failure
      # NOTE this method must stay in sync with #lookup
      method(:int, :count_eops, { target: const_rvalue, value: element.const_lvalue}, constraint:-> { @auxillaries }, visibility: :internal).configure do
        code %{
          int ops = 1;
          size_t slot;
          #{_slot_p} next_slot;
          #{_slot} slot_ = { #{value.to_value_argument} };
          assert(target);
          slot = #{first_slot.(target, :slot_)};
          /* zero state signifies real value, deleted state means slot gets skipped, empty state means end of search */
          while(!#{is_empty}(next_slot = target->slots + slot)) {
            if(!#{is_deleted}(next_slot) && #{element.equal.('next_slot->element', value.to_value_argument)}) return ops;
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
            #{element.const_lvalue} x = #{range.view_front}(&r);
            int e = #{count_eops.(target, '*x')}; assert(e >= 0);
            if(max_eops < e) max_eops = e;
            eops += e;
          }
          fprintf(stream, "\\taverage lookup complexity = %.02f equality tests\\n", (double)eops/target->size);
          fprintf(stream, "\\tmaximum lookup complexity = %d equality tests\\n", max_eops);
          fprintf(stream, "\\tlookup compexity histogram:\\n");
          unsigned* eop_count = (unsigned*)calloc(max_eops+1, sizeof(unsigned)); assert(eop_count);
          for(r = #{range.new}(target); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{element.const_lvalue} x = #{range.view_front}(&r);
            int e = #{count_eops.(target, '*x')}; assert(e >= 0);
            ++eop_count[e];
          }
          for(int i = 1; i <= max_eops; ++i) {
            fprintf(stream, "\\t\\t%d equality test(s) - for %d or %.02f%% of elements\\n", i, eop_count[i], 100.0*eop_count[i]/target->size);
          }
          free(eop_count);        }
      end
    end

  end # IntrusiveHashSet


  class IntrusiveHashSet::Range < ForwardRange

    def render_interface(stream)
      if public?
        render_type_description(stream)
        stream << %{
          /**
            #{ingroup}
            @brief Opaque structure holding state of the hash set's range
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
        dependencies << empty
        code %{
          do ++range->slot; while(!#{empty}(range) && #{iterable.tagged}(range->slots + range->slot));
        }
      end
      view_front.configure do
        dependencies << empty
        code %{
          assert(!#{empty}(range));
          return &(range->slots + range->slot)->element;
        }
      end
    end

  end # Range


end
