# frozen_string_literal: true


require 'autoc/container'
require 'autoc/vector'
require 'autoc/list'


module AutoC


  class HashSet < Container

    def initialize(type, element, visibility = :public)
      super
      @range = Range.new(self, visibility)
      @bucket = Bucket.new(self, element)
      @buckets = Buckets.new(self, @bucket)
      @initial_dependencies << range << @buckets << @bucket
      [@size, @empty].each(&:inline!)
      @compare = nil # Don't know how to order the vectors
    end

    def composite_declarations(stream)
      stream << %$
        /**
        * #{@defgroup} #{type} Hash-based set of unique values of type <#{element.type}>
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
      super
      stream << %$
        /**
         * #{@addtogroup} #{type}
         * @{
         */
        #{define(@size)} {
          assert(self);
          return 0; // TODO
        }
        #{define(@empty)} {
          return #{size}(self) == 0;
        }
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
        super
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

  end


  class HashSet::Buckets < AutoC::Vector

    def initialize(set, bucket) = super(Once.new { "_#{set.type}Buckets" }, bucket, :internal)

  end


end