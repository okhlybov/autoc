# frozen_string_literal: true


require 'autoc/vector'
require 'autoc/list'
require 'autoc/set'


module AutoC


  class HashSet < Set

    def initialize(type, element, visibility = :public)
      super
      @range = Range.new(self, visibility)
      @bucket = Bucket.new(self, element)
      @buckets = Buckets.new(self, @bucket)
      @initial_dependencies << range << @buckets << @bucket
      [@size, @empty].each(&:inline!)
      @compare = nil # Don't know how to order the vectors
      @manager = { minimum_capacity: 8, load_factor: 0.75, expand_factor: 1.5 }
    end

    def composite_declarations(stream)
      stream << %$
        /**
         * #{@defgroup} #{type} Hash-based set of unique values of type <#{element.type}>
         * @{
         */
        typedef struct {
          #{@buckets.type} buckets;
          size_t element_count; /**< @private */
          size_t capacity; /**< @private */
          size_t max_element_count; /**< @private */
        } #{type};
      $
      super
      stream << '/** @} */'
    end

    def composite_definitions(stream)
      stream << %$
        /**
         * #{@addtogroup} #{type}
         * @{
         */
      $
      super
      stream << %$
        #{define(@size)} {
          assert(self);
          return 0; // TODO
        }
        #{define(@empty)} {
          return #{size}(self) == 0;
        }
        /**
         * @brief Perform a rehash
         */
        #{declare} void #{rehash}(#{ptr_type} self);
      $
      stream << %$/** @} */$
    end

    def definitions(stream)
      super
      stream << %$
        #{define(default_create)} {
          // TODO
        }
        #{define(destroy)} {
          // TODO
        }
        void #{create_capacity}(#{ptr_type} self, size_t capacity, int fixed_capacity) {
          assert(self);
          #{@buckets.custom_create}(&self->buckets, self->capacity = AUTOC_MAX(capacity, #{@manager[:minimum_capacity]})*#{@manager[:load_factor]});
          if(fixed_capacity) self->capacity = ~0;
          self->element_count = 0;
        }
        void #{rehash}(#{ptr_type} self) {
          assert(self);
          if(#{size}(self) > self->capacity) {
            #{type} t;
            #{range.type} r;
            #{create_capacity}(&t, self->capacity*#{@manager[:expand_factor]}, 0);
            for(#{range.create}(&r, self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
              #{put}(&t, *#{range.front_view}(&r)); // FIXME tranfser without copying
            }
            // FIXME destroy old self
            *self = t;
          }
        }
        #{define(@contains)} {
          #{@bucket.const_ptr_type} bucket = #{@buckets.view}(&self->buckets, #{element.code(:value)} % #{@buckets.size}(&self->buckets));
          return #{@bucket.contains}(bucket, value);
        }
        #{define(@put)} {
          #{@bucket.const_ptr_type} bucket = #{@buckets.view}(&self->buckets, #{element.code(:value)} % #{@buckets.size}(&self->buckets));
          if(!#{@bucket.contains}(bucket, value)) {
            #{@bucket.push}((#{@bucket.ptr_type})bucket, value);
            return 1;
          } else return 0;
        }
      $
    end


    class HashSet::Range < Range::Forward

      def initialize(*args)
        super
      end

      def composite_declarations(stream)
        stream << %$
          /**
           * #{@defgroup} #{type} Range iterator for <#{iterable.type}> iterable container
           * @{
           */
          typedef struct {
            int dummy; /**< @private */
          } #{type};
        $
        super
        stream << '/** @} */'
      end

      def composite_definitions(stream)
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
          #{define(custom_create)} {
            // TODO
          }
          #{define(@empty)} {
            return 1; // TODO
          }
          #{define(@pop_front)} {
            // TODO
          }
          #{define(@front_view)} {
            return NULL; // TODO
          }
        $
      end
    end


  end


  class HashSet::Bucket < AutoC::List

    def initialize(set, element) = super(Once.new { "_#{set.type}Bucket" }, element, :internal)

    def definitions(stream)
      super
      stream << %$
        static void #{transfer}(#{ptr_type} self, #{element.const_ptr_type} p) {
          #{node}* new_node = #{memory.allocate(node)};
          new_node->element = *p;
          new_node->next_node = self->head_node;
          self->head_node = new_node;
          ++self->node_count;
        }
      $
    end
  end


  class HashSet::Buckets < AutoC::Vector

    def initialize(set, bucket) = super(Once.new { "_#{set.type}Buckets" }, bucket, :internal)

  end


end