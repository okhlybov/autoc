# frozen_string_literal: true


require 'autoc/vector'
require 'autoc/list'
require 'autoc/set'


module AutoC


  # @private
  class HashSet < Set

    prepend Container::Hashable

    def initialize(type, element, visibility: :public)
      super
      raise 'Hash-based set requires hashable element type' unless self.element.hashable?
      @bucket = Bucket.new(self, self.element)
      @buckets = Buckets.new(self, @bucket)
      @range = Range.new(self, visibility: visibility)
      @manager = { minimum_capacity: 8, load_factor: 0.75, expand_factor: 1.5 }
      dependencies << range << @bucket << @buckets
    end

    def canonic_tag = "HashSet<#{element.type}>"

    def composite_interface_declarations(stream)
      stream << %{
        /**
          #{defgroup}
          @brief Hash-based unordered collection of unique elements of type #{element.type}

          For iteration over the set elements refer to @ref #{range.type}.

          @see C++ [std::unordered_set<T>](https://en.cppreference.com/w/cpp/container/unordered_set)

          @since 2.0
        */
        /**
          #{ingroup}
          @brief Opaque structure holding state of the hash set
          @since 2.0
        */
        typedef struct {
          #{@buckets.type} buckets; /**< @private */
          size_t element_count; /**< @private */
          size_t capacity; /**< @private */
        } #{type};
      }
      super
    end

    private def configure
      super
      def_method :void, :create_capacity, { self: type, capacity: :size_t, manage_capacity: :int } do
        code %{
          assert(self);
          #{@buckets.custom_create}(&self->buckets, self->capacity = AUTOC_MAX(capacity, #{@manager[:minimum_capacity]})*#{@manager[:load_factor]});
          if(!manage_capacity) self->capacity = ~0;
          self->element_count = 0;
        }
        header %{
          @brief Create a set with specified initial capacity

          @param[out] self container to be initialized
          @param[in] capacity desired capacity
          @param[in] manage_capacity permit expanding the storage if non-zero

          This function creates an empty hash set configured for accomodating `capacity` elements.

          The `manage_capacity` flag determines whether the set is allowed to grow when the capacity is exceeded.
          Non-zero value allows expanding the storage (which incurs implicit rehashing) if needed.
          Zero value, on the contrary, fixes the capacity to initial value despite the demand for expanding.
          The set created with @ref #{default_create} sets this value to non-zero.

          @note Previous contents of `*self` is overwritten.

          @since 2.0
        }
      end
      size.inline_code %{
        assert(self);
        return self->element_count;
      }
      empty.inline_code %{
        assert(self);
        return #{size}(self) == 0;
      }
      default_create.code %{
        #{create_capacity}(self, #{@manager[:minimum_capacity]}, 1);
      }
      destroy.code %{
        #{@buckets.destroy('self->buckets')};
      }
      copy.code %{
        #{range.type} r;
        assert(self);
        assert(source);
        #{create_capacity}(self, #{size}(source), 0);
        for(r = #{get_range}(source); !#{range.empty}(&r); #{range.pop_front}(&r)) {
          #{put}(self, *#{range.view_front}(&r));
        }
      }
      equal.code %{
        return #{@buckets.equal}(&self->buckets, &other->buckets);
      }
      lookup.code %{
        return #{@bucket.lookup}(#{_locate}(self, value), value);
      }
      put.code %{
        #{@bucket.const_ptr_type} bucket = #{_locate}(self, value);
        if(!#{@bucket.contains}(bucket, value)) {
          #{@bucket.push_front}((#{@bucket.ptr_type})bucket, value);
          ++self->element_count;
          #{_rehash}(self);
          return 1;
        } else return 0;
      }
      push.code %{
        /* FIXME get rid of code duplication */
        int replace = #{remove}(self, value);
        #{put}(self, value);
        return replace;
      }
      remove.code %{
        #{@bucket.const_ptr_type} bucket = #{_locate}(self, value);
        if(#{@bucket.remove}((#{@bucket.ptr_type})bucket, value)) {
          --self->element_count;
          return 1;
        } else return 0;
      }
    end

    def definitions(stream)
      stream << %{
        static #{@bucket.const_ptr_type} #{_locate}(#{const_ptr_type} self, #{element.const_type} value) {
          return #{@buckets.view}(&self->buckets, #{element.hash_code(:value)} % #{@buckets.size}(&self->buckets));
        }
        /* Push value to the set bypassing the element's copy function */
        static void #{adopt}(#{ptr_type} self, #{element.const_type} value) {
          #{@bucket.adopt}((#{@bucket.ptr_type})#{_locate}(self, value), value);
        }
        /* Perform a rehash accomodating new actual size */
        static void #{_rehash}(#{ptr_type} self) {
          assert(self);
          if(#{size}(self) > self->capacity) {
            #{type} t;
            #{range.type} r;
            #{create_capacity}(&t, self->capacity*#{@manager[:expand_factor]}, 0);
            for(r = #{get_range}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
              #{adopt}(&t, *#{range.view_front}(&r));
            }
            #{@buckets.dispose}(&self->buckets);
            *self = t;
          }
        }
      }
      super
    end


    # @private
    class HashSet::Range < Range::Forward

      def initialize(iterable, visibility:)
        super
        @bucket = iterable.instance_variable_get(:@bucket)
        @buckets = iterable.instance_variable_get(:@buckets)
      end

      def composite_interface_declarations(stream)
        stream << %{
          /**
            #{defgroup}
            @ingroup #{iterable.type}

              @brief #{canonic_desc}

              This range implements the @ref #{archetype} archetype.

              @see @ref Range

              @since 2.0
          */
          /**
            @brief Opaque structure holding state of the set's range
            @since 2.0
          */
          typedef struct {
            #{@bucket.range.type} bucket_range; /**< @private */
            #{@buckets.range.type} buckets_range; /**< @private */
          } #{type};
        }
        super
      end

      private def configure
        super
        custom_create.code %{
          assert(self);
          assert(iterable);
          #{@buckets.range.custom_create}(&self->buckets_range, &iterable->buckets);
          #{_next_bucket}(self, 1);
        }
        empty.code %{
          assert(self);
          return #{@bucket.range.empty}(&self->bucket_range);
        }
        pop_front.code %{
          assert(self);
          #{@bucket.range.pop_front}(&self->bucket_range);
          if(#{@bucket.range.empty}(&self->bucket_range)) #{_next_bucket}(self, 0);
        }
        view_front.code %{
          assert(self);
          assert(!#{empty}(self));
          return #{@bucket.range.view_front}(&self->bucket_range);
        }
      end

      def definitions(stream)
        stream << %{
          static void #{_next_bucket}(#{ptr_type} self, int new_bucket_range) {
            do {
              if (new_bucket_range) #{@bucket.range.custom_create}(&self->bucket_range, #{@buckets.range.view_front}(&self->buckets_range));
              else new_bucket_range = 1; /* Skip the first creation act only */
              if (!#{@bucket.range.empty}(&self->bucket_range)) break;
              else #{@buckets.range.pop_front}(&self->buckets_range);
            } while(!#{@buckets.range.empty}(&self->buckets_range));
          }
        }
        super
      end
    end


  end


  # @private
  class HashSet::Bucket < AutoC::List

    def initialize(set, element) = super(Once.new { set.decorate_identifier(:_L) }, element, visibility: :internal)

    private def configure
      super
      def_method :void, :adopt, { self: type, value: element.const_type } do
        code %{
          /* Derived from #{push} */
          #{@node}* new_node = #{memory.allocate(@node)};
          new_node->next_node = self->head_node;
          self->head_node = new_node;
          new_node->element = value;
          ++self->node_count;
        }
      end
      def_method :void, :dispose, { self: type } do
        code %{
          /* Derived from #{drop}() */
          while(!#{empty}(self)) {
            #{@node}* this_node = self->head_node; assert(this_node);
            self->head_node = self->head_node->next_node;
            #{memory.free(:this_node)};
            --self->node_count;
          }
        }
      end
    end

  end


  # @private
  class HashSet::Buckets < AutoC::Vector

    def initialize(set, bucket) = super(Once.new { set.decorate_identifier(:_V) }, bucket, visibility: :internal)

    private def configure
      super
      def_method :void, :dispose, { self: type } do
        code %{
          #{range.type} r;
          for(r = #{get_range}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{element.dispose}((#{element.ptr_type})#{range.view_front}(&r));
          }
          #{memory.free('self->elements')};
        }
      end
    end

  end


end