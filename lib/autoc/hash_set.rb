# frozen_string_literal: true


require 'autoc/vector'
require 'autoc/list'
require 'autoc/set'


module AutoC


  using STD::Coercions


  class HashSet < Set

    def range = @range ||= Range.new(self, visibility: visibility)

    def _bucket = @_bucket ||= List.new(identifier(:_list, abbreviate: true), element, maintain_size: false, visibility: :internal)

    def _buckets = @_buckets ||= Vector.new(identifier(:_vector, abbreviate: true), _bucket, visibility: :internal)

    def initialize(*args, **kws)
      super
      dependencies << _buckets
    end

    def render_interface(stream)
      if public?
        stream << %{
          /**
            #{defgroup}
            @brief Hash-based unordered collection of unique elements of type #{element}

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
          #{_buckets} buckets; /**< @private */
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
          capacity = 1 << (bits+1);
          target->hash_mask = capacity-1; /* fast bucket location for value: hash_code(value) & hash_mask */
          #{_buckets.custom_create.('target->buckets', capacity)};
          assert(#{_buckets.size.('target->buckets')} % 2 == 0);
        }
      end
      method(_bucket.const_lvalue, :_find_bucket, { target: const_rvalue, value: element.const_rvalue }, visibility: :internal).configure do
        # Find slot based on the value hash code
        dependencies << _buckets.view
        inline_code %{
          return #{_buckets.view.('target->buckets', element.hash_code.(value) + '&target->hash_mask')};
        }
      end
      method(:void, :_expand, { target: lvalue, force: :int.const_rvalue }, visibility: :internal).configure do
        code %{
          #{type} set;
          #{_buckets.range} r;
          assert(target);
          /* capacity threshold == 1.0 */
          if(force || target->size >= #{_buckets.size.('target->buckets')}) {
            #{create_capacity.(:set, _buckets.size.('target->buckets') + '*2')};
            /* move elements to newly allocated set */
            for(r = #{_buckets.range.new.('target->buckets')}; !#{_buckets.range.empty.(:r)}; #{_buckets.range.pop_front.(:r)}) {
              #{_bucket.lvalue} src = (#{_bucket.lvalue})#{_buckets.range.view_front.(:r)};
              while(!#{_bucket.empty.('*src')}) {
                /* direct node relocation from original to new list bypassing node reallocation & payload copying */
                #{_bucket._node_p} node = #{_bucket._pull_node.('*src')};
                #{_bucket.lvalue} dst = (#{_bucket.lvalue})#{_find_bucket.(target, 'node->element')};
                #{_bucket._push_node.('*dst', '*node')};
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
          #{_bucket.lvalue} b;
          assert(target);
          b = (#{_bucket.lvalue})#{_find_bucket.(target, value)};
          c = #{_bucket.remove.('*b', value)};
          if(c) --target->size;
          return c;
        }
      end
      put.configure do
        code %{
          #{_bucket.lvalue} b;
          assert(target);
          b = (#{_bucket.lvalue})#{_find_bucket.(target, value)};
          if(!#{_bucket.find_first.('*b', value)}) {
            #{_expand.(target, 0)};
            #{_bucket.push_front.('*b', value)};
            ++target->size;
            return 1;
          } else return 0;
        }
      end
      push.configure do
        code %{
          #{_bucket.lvalue} b;
          assert(target);
          b = (#{_bucket.lvalue})#{_find_bucket.(target, value)};
          if(#{_bucket._replace_first.('*b', value)}) {
            return 1;
          } else {
            /* add brand new value */
            #{_expand.(target, 0)};
            #{_bucket.push_front.('*b', value)};
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
          #{_bucket.const_lvalue} b = #{_find_bucket.(target, value)};
          return #{_bucket.find_first.('*b', value)};
        }
      end
      copy.configure do
        code %{
          assert(target);
          assert(source);
          #{_buckets.copy.('target->buckets', 'source->buckets')};
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
          #{_bucket.const_lvalue} b;
          assert(target);
          b = #{_find_bucket.(target, value)};
          return #{_bucket.contains.('*b', value)};
        }
      end
      destroy.configure do
        code %{
          assert(target);
          #{_buckets.destroy.('target->buckets')};
        }
      end
      hash_code.configure do
        code %{
          #{range} r;
          size_t hash;
          for(hash = AUTOC_HASHER_SEED, r = #{range.new.(target)}; !#{range.empty.(:r)}; #{range.pop_front.(:r)}) {
            #{element.const_lvalue} e = #{range.view_front.(:r)};
            hash ^= #{element.hash_code.('*e')}; /* default incremental hasher is applicable to ordered collections only */
          }
          return hash;
        }
      end
    end

  end # HashSet


  class HashSet::Range < ForwardRange

    def render_interface(stream)
      if public?
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
          #{_buckets} buckets; /**< @private */
          #{_bucket} bucket; /**< @private */
        } #{signature};
      }
    end

    def _bucket = @_bucket ||= iterable._bucket.range

    def _buckets = @_buckets ||= iterable._buckets.range

  private

    def configure
      super
      method(:void, :_advance, { range: rvalue } ).configure do
        code %{
          assert(range);
          while(1) {
            if(#{_bucket.empty.('range->bucket')}) {
              /* current bucket's range is empty - iterate forward to the next one */
              #{_buckets.pop_front.('range->buckets')};
              if(#{_buckets.empty.('range->buckets')}) {
                /* all buckets are iterated through, bucket range is also empty - end of set */
                break;
              } else {
                /* advance to the new (possibly empty) bucket */
                #{iterable._bucket.const_lvalue} b = #{_buckets.view_front.('range->buckets')};
                range->bucket = #{_bucket.new.('*b')};
              }
            } else {
              /* current bucket's range is not empty - no need to proceed */
              break;
            }
          }
        }
      end
      custom_create.configure do
        code %{
          assert(range);
          assert(iterable);
          range->buckets = #{_buckets.new.('iterable->buckets')};
          /* get the first bucket's range regardless of its emptiness status */
          #{_iterable._bucket.const_lvalue} b = #{_buckets.view_front.('range->buckets')};
          range->bucket = #{_bucket.new.('*b')};
          /* actually advance to the first non-empty bucket */
          #{_advance.(range)};
        }
      end
      empty.configure do
        code %{
          assert(range);
          return #{_bucket.empty.('range->bucket')};
        }
      end
      pop_front.configure do
        code %{
          assert(range);
          #{_bucket.pop_front.('range->bucket')};
          #{_advance.(range)};
        }
      end
      view_front.configure do
        code %{
          assert(range);
          assert(!#{empty.(range)});
          return #{_bucket.view_front.('range->bucket')};
        }
      end
    end

  end # Range


end