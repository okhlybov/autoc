require 'autoc/type'
require 'autoc/memory'
require 'autoc/vector'
require 'autoc/list'
require 'autoc/hasher'


module AutoC


  #
  class HashSet < Container

    include Container::Hashable

    %i(create destroy).each {|s| redirect(s, 1)}
    %i(clone equal).each {|s| redirect(s, 2)}

    attr_reader :range

    def initialize(type, element, prefix: nil, deps: [])
      super(type, element, prefix, deps)
      @bucket = List.new("_#{self.type}Bucket", self.element)
      @buckets = Vector.new("_#{self.type}Buckets", @bucket)
      @range = Range.new(self, @buckets, @bucket)
      self.dependencies << @range
      @weak << @range
    end

    def interface
      @stream << %$
        typedef struct #{type} #{type};
        struct #{type} {
          #{@buckets.type} buckets;
          size_t element_count, capacity;
          float overfill;
        };
        #{inline} size_t #{size}(const #{type}* self) {
          assert(self);
          return self->element_count;
        }
        #define #{empty}(self) (#{size}(self) == 0)
        #define #{create}(self) #{createEx}(self, 16)
        #{declare} #{type}* #{createEx}(#{type}* self, size_t capacity);
        #{declare} void #{destroy}(#{type}* self);
        #define #{rehash}(self, capacity) #{_rehash}(self, capacity, 1)
        #{declare} void #{_rehash}(#{type}* self, size_t capacity, int live);
      $
      @stream << %$
        #{declare} int #{put}(#{type}* self, #{element.type} element);
      $ if element.cloneable?
      super
    end

    def definitions
      @stream << %$
        #{define} void #{_rehash}(#{type}* self, size_t capacity, int live) {
          #{type} origin = *self;
          assert(self);
          assert(self->overfill > 0);
          #{createEx}(self, (self->capacity = capacity)/self->overfill);
          if(live) {
            #{range.type} r;
            /* TODO employ light element transfer instead of a full fledged copying */
            for(#{range.create}(&r, &origin); !#{range.empty}(&r); #{range.popFront}(&r)) #{put}(self, *#{range.frontView}(&r));
            #{destroy}(&origin);
          }
        }
        #{define} #{type}* #{createEx}(#{type}* self, size_t capacity) {
          assert(self);
          self->element_count = 0;
          self->overfill = 1.25;
          #{_rehash}(self, capacity, 0);
          assert(#{@buckets.size}(&self->buckets) > 0);
          return self;
        }
        #{define} void #{destroy}(#{type}* self) {
          assert(self);
          #{@buckets.destroy}(&self->buckets);
        }
      $
      @stream << %$
        static #{@bucket.type}* #{_findBucket}(#{type}* self, #{element.type} element) {
          return (#{@bucket.type}*)#{@buckets.view}(&self->buckets, #{element.identify(:element)} % #{@buckets.size}(&self->buckets));
        }
        #{define} int #{put}(#{type}* self, #{element.type} element) {
        #{@bucket.type}* bucket;
        assert(self);
        if(#{@bucket.contains}(bucket = #{_findBucket}(self, element), element)) {
          return 0;
        } else {
          #{@bucket.push}(bucket, element);
          return 1;
        }
      }
      $ if element.cloneable?
      # TODO equal()
      super
    end
  end # HashSet


  class HashSet::Range < Range::Input

    alias declare inline

    def initialize(container, buckets, bucket)
      super(container, nil, [@bucket = bucket, @bucketsRange = buckets.range, @bucketRange = bucket.range])
    end

    def interface
      @stream << %$
        typedef struct {
          #{@bucketsRange.type} buckets_range;
          #{@bucketRange.type} bucket_range;
        } #{type};
      $
      super
      @stream << %$
        AUTOC_EXTERN void #{_bucketFF}(#{type}* self);
        #{inline} #{type}* #{create}(#{type}* self, const #{@container.type}* container) {
          assert(self);
          assert(container);
          #{@bucketsRange.create}(&self->buckets_range, &container->buckets);
          #{@bucketRange.create}(&self->bucket_range, #{@bucketsRange.frontView}(&self->buckets_range));
          #{_bucketFF}(self);
          return self;
        }
        #{inline} int #{empty}(const #{type}* self) {
          assert(self);
          return #{@bucketRange.empty}(&self->bucket_range);
        }
        #{inline} void #{popFront}(#{type}* self) {
          /*assert(self);*/
          assert(!#{empty}(self));
          if(#{@bucketRange.empty}(&self->bucket_range)) {
            #{_bucketFF}(self);
          } else {
            #{@bucketRange.popFront}(&self->bucket_range);
          }
        }
        #{inline} const #{@container.element.type}* #{frontView}(const #{type}* self) {
          assert(self);
          assert(!#{@bucketRange.empty}(&self->bucket_range));
          return #{@bucketRange.frontView}(&self->bucket_range);
        }
      $
      @stream << %$
        #{inline} #{@container.element.type} #{front}(const #{type}* self) {
          #{@container.element.type} result;
          const #{@container.element.type}* e = #{frontView}(self);
          #{@container.element.clone(:result, '*e')};
          return result;
        }
      $ if @container.element.cloneable?
    end

    def definitions
      super
      @stream << %$
        /* Fast forward to the next non-empty bucket if any */
        #{define} void #{_bucketFF}(#{type}* self) {
          assert(self);
          while(#{@bucket.empty}(#{@bucketsRange.frontView}(&self->buckets_range))) {
            #{@bucketsRange.popFront}(&self->buckets_range);
            if(#{@bucketsRange.empty}(&self->buckets_range)) return;
          }
          #{@bucketRange.create}(&self->bucket_range, #{@bucketsRange.frontView}(&self->buckets_range));
        }
      $
    end

  end # Range

end # AutoC