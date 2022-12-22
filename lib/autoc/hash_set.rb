# frozen_string_literal: true


require 'autoc/vector'
require 'autoc/list'
require 'autoc/set'


module AutoC


  using STD::Coercions


  class HashSet < Set

    def range = @range ||= Range.new(self, visibility: visibility)

    def bucket = @bucket ||= List.new(identifier(:_L), element, maintain_size: false, visibility: :internal)

    def buckets = @buckets ||= Vector.new(identifier(:_V), bucket, visibility: :internal)

    def initialize(*args, **kws)
      super
      dependencies << buckets << bucket
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
          #{buckets} buckets; /**< @private */
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
          /* fix capacity to become the power of 2, encompassing original value */
          if(capacity % 2 == 0) --capacity;
          while(capacity >>= 1) ++bits;
          capacity = 1 << (bits+1);
          target->hash_mask = capacity-1; /* fast bucket location for value: hash_code(value) & hash_mask */
          #{buckets.custom_create.('target->buckets', capacity)};
          assert(#{buckets.size.('target->buckets')} % 2 == 0);
        }
      end
      method(bucket.const_lvalue, :_find_bucket, { target: const_rvalue, value: element.const_rvalue }, visibility: :internal).configure do
        # Find slot based on the value hash code
        dependencies << buckets.view
        inline_code %{
          return #{buckets.view.('target->buckets', element.hash_code.(value) + '&target->hash_mask')};
        }
      end
      method(:void, :_expand, { target: lvalue, force: :int.const_rvalue }, visibility: :internal).configure do
        code %{
          #{type} set;
          #{buckets.range} r;
          assert(target);
          /* capacity threshold == 1.0 */
          if(force || target->size >= #{buckets.size.('target->buckets')}) {
            #{create_capacity.(:set, buckets.size.('target->buckets') + '*2')};
            /* move elements to newly allocated set */
            for(r = #{buckets.range.new.('target->buckets')}; !#{buckets.range.empty.(:r)}; #{buckets.range.pop_front.(:r)}) {
              #{bucket.lvalue} src = (#{bucket.lvalue})#{buckets.range.view_front.(:r)};
              while(!#{bucket.empty.('*src')}) {
                /* direct node relocation from original to new list bypassing node reallocation & payload copying */
                #{bucket.node_p} node = #{bucket._pull_node.('*src')};
                #{bucket.lvalue} dst = (#{bucket.lvalue})#{_find_bucket.(target, 'node->element')};
                #{bucket._push_node.('*dst', '*node')};
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
          #{bucket.lvalue} b;
          assert(target);
          b = (#{bucket.lvalue})#{_find_bucket.(target, value)};
          c = #{bucket.remove.('*b', value)};
          if(c) --target->size;
          return c;
        }
      end
      put.configure do
        code %{
          #{bucket.lvalue} b;
          assert(target);
          b = (#{bucket.lvalue})#{_find_bucket.(target, value)};
          if(!#{bucket.find_first.('*b', value)}) {
            #{_expand.(target, 0)};
            #{bucket.push_front.('*b', value)};
            ++target->size;
            return 1;
          } else return 0;
        }
      end
      push.configure do
        code %{
          #{bucket.lvalue} b;
          assert(target);
          b = (#{bucket.lvalue})#{_find_bucket.(target, value)};
          if(#{bucket._replace_first.('*b', value)}) {
            return 1;
          } else {
            /* add brand new value */
            #{_expand.(target, 0)};
            #{bucket.push_front.('*b', value)};
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
          #{bucket.const_lvalue} b = #{_find_bucket.(target, value)};
          return #{bucket.find_first.('*b', value)};
        }
      end
      copy.configure do
        code %{
          assert(target);
          assert(source);
          #{buckets.copy.('target->buckets', 'source->buckets')};
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
          #{bucket.const_lvalue} b;
          assert(target);
          b = #{_find_bucket.(target, value)};
          return #{bucket.contains.('*b', value)};
        }
      end
      destroy.configure do
        code %{
          assert(target);
          #{buckets.destroy.('target->buckets')};
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
          #{iterable.buckets.range} buckets; /**< @private */
          #{iterable.bucket.range} bucket; /**< @private */
        } #{signature};
      }
    end

  private

    def configure
      super
      method(:void, :_next_bucket, { range: rvalue, initial: :int.rvalue } ).configure do
        code %{
          assert(range);
          do {
            if(initial) {
              #{iterable.bucket.const_lvalue} b = #{iterable.buckets.range.view_front.('range->buckets')};
              range->bucket = #{iterable.bucket.range.new.('*b')};
            } else initial = 0;
            if(#{iterable.bucket.range.empty.('range->bucket')}) {
              #{iterable.buckets.range.pop_front.('range->buckets')};
            } else break;
          } while(! #{iterable.buckets.range.empty.('range->buckets')});
        }
      end
      custom_create.configure do
        code %{
          assert(range);
          assert(iterable);
          range->buckets = #{_iterable.buckets.range.new.('iterable->buckets')};
          #{_next_bucket.(range, 1)};
        }
      end
      empty.configure do
        code %{
          assert(range);
          return #{iterable.bucket.range.empty.('range->bucket')};
        }
      end
      pop_front.configure do
        code %{
          assert(range);
          #{iterable.bucket.range.pop_front.('range->bucket')};
          if(#{iterable.bucket.range.empty.('range->bucket')}) #{_next_bucket.(range, 0)};
        }
      end
      view_front.configure do
        code %{
          assert(range);
          assert(!#{empty.(range)});
          return #{iterable.bucket.range.view_front.('range->bucket')};
        }
      end
    end

  end # Range


end