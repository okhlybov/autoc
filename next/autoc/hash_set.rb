# frozen_string_literal: true


require 'autoc/vector'
require 'autoc/list'
require 'autoc/set'


module AutoC


  # @private
  class BasicHashSet < Set

    include Container::Hashable

    def initialize(type, element, visibility = :public)
      super
      raise 'Hash-based set requires hashable element type' unless self.element.hashable?
      @bucket = Bucket.new(self, element)
      @buckets = Buckets.new(self, @bucket)
      @range = Range.new(self, visibility)
      dependencies << range << @bucket << @buckets
      @create_capacity = function(self, :create_capacity, 1, { self: type, capacity: :size_t, fixed_capacity: :int }, :void)
      [@size, @empty].each(&:inline!)
      @compare = nil # Don't know how to order the vectors
      @manager = { minimum_capacity: 8, load_factor: 0.75, expand_factor: 1.5 }
    end

    def canonic_tag = "HashSet<#{element.type}>"

    def composite_interface_declarations(stream)
      stream << %$
        /**
         * #{@defgroup} #{type} #{canonic_tag} :: hash-based unordered collection of unique elements of type #{element.type}
         * @{
         */
        typedef struct {
          #{@buckets.type} buckets; /**< @private */
          size_t element_count; /**< @private */
          size_t capacity; /**< @private */
        } #{type};
      $
      super
      stream << '/** @} */'
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
        /**
         * @brief Create a set with specified initial capacity
         */
        #{declare(@create_capacity)};
        #{define(@size)} {
          assert(self);
          return self->element_count;
        }
        #{define(@empty)} {
          return #{size}(self) == 0;
        }
      $
      stream << '/** @} */'
    end

    def definitions(stream)
      super
      stream << %$
        static #{@bucket.const_ptr_type} #{_locate}(#{const_ptr_type} self, #{element.const_type} value) {
          return #{@buckets.view}(&self->buckets, #{element.code(:value)} % #{@buckets.size}(&self->buckets));
        }
        /* Push value to the set bypassing the element's copy function */
        static void #{_adopt}(#{ptr_type} self, #{element.const_type} value) {
          #{@bucket._adopt}((#{@bucket.ptr_type})#{_locate}(self, value), value);
        }
        static void #{_rehash}(#{ptr_type} self) {
          assert(self);
          if(#{size}(self) > self->capacity) {
            #{type} t;
            #{create_capacity}(&t, self->capacity*#{@manager[:expand_factor]}, 0);
            for(#{range.type} r = #{get_range}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
              #{_adopt}(&t, *#{range.front_view}(&r));
            }
            #{@buckets._dispose}(&self->buckets);
            *self = t;
          }
        }
        #{define(default_create)} {
          #{create_capacity}(self, #{@manager[:minimum_capacity]}, 0);
        }
        #{define(destroy)} {
          #{@buckets.destroy('self->buckets')};
        }
        #{define(@create_capacity)} {
          assert(self);
          #{@buckets.custom_create}(&self->buckets, self->capacity = AUTOC_MAX(capacity, #{@manager[:minimum_capacity]})*#{@manager[:load_factor]});
          if(fixed_capacity) self->capacity = ~0;
          self->element_count = 0;
        }
        #{define(@purge)} {
          for(#{@buckets.range.type} r = #{@buckets.get_range}(&self->buckets); !#{@buckets.range.empty}(&r); #{@buckets.range.pop_front}(&r)) {
            #{@bucket.purge}((#{@bucket.ptr_type})#{@buckets.range.front_view}(&r));
          }
        }
        #{define(copy)} {
          assert(self);
          assert(source);
          #{create_capacity}(self, #{size}(source), 0);
          for(#{range.type} r = #{get_range}(source); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{put}(self, *#{range.front_view}(&r));
          }
        }
        #{define(equal)} {
          return #{@buckets.equal}(&self->buckets, &other->buckets);
        }
        #{define(@contains)} {
          return #{@bucket.contains}(#{_locate}(self, value), value);
        }
        #{define(@view)} {
          return #{@bucket.find_view}(#{_locate}(self, value), value);
        }
        #{define(@put)} {
          #{@bucket.const_ptr_type} bucket = #{_locate}(self, value);
          if(!#{@bucket.contains}(bucket, value)) {
            #{@bucket.push}((#{@bucket.ptr_type})bucket, value);
            ++self->element_count;
            #{_rehash}(self);
            return 1;
          } else return 0;
        }
        #{define(@force)} {
          /* FIXME get rid of code duplication */
          int replace = #{remove}(self, value);
          #{put}(self, value);
          return replace;
        }
        #{define(@remove)} {
          #{@bucket.const_ptr_type} bucket = #{_locate}(self, value);
          if(#{@bucket.remove}((#{@bucket.ptr_type})bucket, value)) {
            --self->element_count;
            return 1;
          } else return 0;
        }
      $
    end


    class BasicHashSet::Range < Range::Forward

      def initialize(*args)
        super
        @bucket_range = iterable.instance_variable_get(:@bucket).range
        @buckets_range = iterable.instance_variable_get(:@buckets).range
      end

      def composite_interface_declarations(stream)
        stream << %$
          /**
           * #{@defgroup} #{type} #{canonic_tag} :: range iterator for the iterable container #{iterable.canonic_tag}
           * @{
           */
          typedef struct {
            #{@bucket_range.type} bucket_range; /**< @private */
            #{@buckets_range.type} buckets_range; /**< @private */
          } #{type};
        $
        super
        stream << '/** @} */'
      end

      def composite_interface_definitions(stream)
        stream << %$
          /**
           * #{@addtogroup} #{type}
           * @{
           */
        $
        super
        stream << '/** @} */'
      end

      def definitions(stream)
        super
        stream << %$
          static void #{_next_bucket}(#{ptr_type} self, int new_bucket_range) {
            do {
              if (new_bucket_range) #{@bucket_range.custom_create}(&self->bucket_range, #{@buckets_range.front_view}(&self->buckets_range));
              else new_bucket_range = 1; /* Skip the first creation act only */
              if (!#{@bucket_range.empty}(&self->bucket_range)) break;
              else #{@buckets_range.pop_front}(&self->buckets_range);
            } while(!#{@buckets_range.empty}(&self->buckets_range));
          }
          #{define(custom_create)} {
            assert(self);
            assert(iterable);
            #{@buckets_range.custom_create}(&self->buckets_range, &iterable->buckets);
            #{_next_bucket}(self, 1);
          }
          #{define(@empty)} {
            assert(self);
            return #{@bucket_range.empty}(&self->bucket_range);
          }
          #{define(@pop_front)} {
            assert(self);
            #{@bucket_range.pop_front}(&self->bucket_range);
            if(#{@bucket_range.empty}(&self->bucket_range)) #{_next_bucket}(self, 0);
          }
          #{define(@front_view)} {
            assert(self);
            assert(!#{empty}(self));
            return #{@bucket_range.front_view}(&self->bucket_range);
          }
        $
      end
    end


  end


  class BasicHashSet::Bucket < AutoC::List

    def initialize(set, element) = super(Once.new { set.decorate_identifier(:_bucket) }, element, :internal)

    def forward_declarations(stream)
      super
      stream << %$
        #{declare} void #{_adopt}(#{ptr_type} self, #{element.const_type} value);
        #{declare} void #{_dispose}(#{ptr_type} self);
      $
    end

    def definitions(stream)
      super
      stream << %$
        /* Push value to the list bypassing the element's copy function */
        #{define} void #{_adopt}(#{ptr_type} self, #{element.const_type} value) {
          /* Derived from #{push}() */
          #{node}* new_node = #{memory.allocate(node)};
          new_node->next_node = self->head_node;
          self->head_node = new_node;
          new_node->element = value;
          ++self->node_count;
        }
        /* Free the storage without calling the element's destructors */
        #{define} void #{_dispose}(#{ptr_type} self) {
          /* Derived from #{drop}() */
          while(!#{empty}(self)) {
            #{node}* this_node = self->head_node; assert(this_node);
            self->head_node = self->head_node->next_node;
            #{memory.free(:this_node)};
            --self->node_count;
          }
        }
      $
    end

  end


  class BasicHashSet::Buckets < AutoC::Vector

    def initialize(set, bucket) = super(Once.new { set.decorate_identifier(:_buckets) }, bucket, :internal)

    def definitions(stream)
      super
      stream << %$
        /* Free the storage disposing the elements in turn */
        #{define} void #{_dispose}(#{ptr_type} self) {
          for(#{range.type} r = #{get_range}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{element._dispose}((#{element.ptr_type})#{range.front_view}(&r));
          }
          #{memory.free('self->elements')};
        }
      $
    end

  end


  class HashSet < BasicHashSet
    include Set::Operations
  end

end