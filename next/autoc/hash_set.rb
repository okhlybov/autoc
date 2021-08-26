require 'autoc/container'
require 'autoc/vector'
require 'autoc/list'


module AutoC


  class HashSet < Container

    def initialize(type, element)
      super
      @range = Range.new(self)
      @bucket = Bucket.new(self, element)
      @buckets = Buckets.new(self, @bucket)
      @initial_dependencies << range << @bucket << @buckets
      [@size, @empty].each(&:inline!)
      @compare = nil # Don't know how to order the vectors
    end

    def interface_declarations(stream)
      stream << %$
        /**
        * @defgroup #{type} Hash-based set of unique values of type <#{element.type}>
        * @{
        */
        typedef struct {
          int dummy; /**< @private */
        } #{type};
      $
      super
      stream << '/** @} */'
    end

    def interface_definitions(stream)
      super
      stream << %$
        /**
         * @addtogroup #{type}
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

      def interface_declarations(stream)
        stream << %$
          /**
          * @defgroup #{type} Range iterator for <#{iterable.type}> iterable container
          * @{
          */
          typedef struct {
            int dummy; /**< @private */
          } #{type};
        $
        super
        stream << '/** @} */'
      end

      def interface_definitions(stream)
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

    def type = @type ||= "_#{@set.type}Bucket"

    def initialize(set, element)
      @set = set
      super(nil, element)
    end

  end


  class HashSet::Buckets < AutoC::Vector

    def type = @type ||= "_#{@set.type}Buckets"

    def initialize(set, bucket)
      @set = set
      super(nil, bucket)
    end

  end


end