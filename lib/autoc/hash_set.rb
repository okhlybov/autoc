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

    def interface_declarations(stream)
      super
      stream << %$
        typedef struct #{type} #{type};
        struct #{type} {
          #{@buckets.type} buckets;
          size_t element_count, capacity;
          float overfill;
        };
      $
    end

    def interface_definitions(stream)
      super
      stream << %$
        #{declare} #{type}* #{createEx}(#{type}* self, size_t capacity);
        #{define} #{type}* #{create}(#{type}* self) {
          assert(self);
          return #{createEx}(self, 16);
        }
        #{define} size_t #{size}(const #{type}* self) {
          assert(self);
          return self->element_count;
        }
        #{define} int #{empty}(const #{type}* self) {
          assert(self);
          return #{size}(self) == 0;
        }
        #{declare} void #{destroy}(#{type}* self);
        #{declare} void #{_rehash}(#{type}* self, size_t capacity, int live);
        #{define} void #{rehash}(#{type}* self, size_t capacity) {
          assert(self);
          #{_rehash}(self, capacity, 1);
        }
      $
      stream << %$
        #{declare} int #{put}(#{type}* self, const #{element.type} value);
      $ if element.cloneable?
      stream << %$
        #{declare} const #{element.type}* #{findView}(const #{type}* self, const #{element.type} value);
        #{define} int #{contains}(const #{type}* self, const #{element.type} value) {
          return #{findView}(self, value) != NULL;
        }
        #{declare} int #{subsetOf}(const #{type}* self, const #{type}* other);
        #{declare} int #{remove}(#{type}* self, const #{element.type} what);
      $ if element.equality_testable?
      stream << %$
        #{define} int #{equal}(const #{type}* self, const #{type}* other) {
          assert(self);
          assert(other);
          return #{size}(self) == #{size}(other) && #{subsetOf}(self, other) && #{subsetOf}(other, self);
        }
      $ if equality_testable?
    end

    def definitions(stream)
      stream << %$
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
          self->overfill = 2.0;
          #{_rehash}(self, capacity, 0);
          assert(#{@buckets.size}(&self->buckets) > 0);
          return self;
        }
        #{define} void #{destroy}(#{type}* self) {
          assert(self);
          #{@buckets.destroy}(&self->buckets);
        }
      $
      stream << %$
        static #{@bucket.type}* #{findBucket}(#{type}* self, const #{element.type} value) {
          return (#{@bucket.type}*)#{@buckets.view}(&self->buckets, #{element.identify(:value)} % #{@buckets.size}(&self->buckets));
        }
        #{define} int #{put}(#{type}* self, const #{element.type} value) {
        #{@bucket.type}* bucket;
        assert(self);
        if(#{@bucket.contains}(bucket = #{findBucket}(self, value), value)) {
          return 0;
        } else {
          #{@bucket.push}(bucket, value);
          return 1;
        }
      }
      $ if element.cloneable?
      stream << %$
        #{define} const #{element.type}* #{findView}(const #{type}* self, const #{element.type} value) {
          assert(self);
          return #{@bucket.findView}(#{findBucket}(self, value), value);
        }
        #{define} int #{subsetOf}(const #{type}* self, const #{type}* other) {
          #{range} r;
          assert(self);
          assert(other);
          if(#{size}(self) > #{size}(other)) return 0;
          for(#{range.create}(&r, self); !#{range.empty}(&r); #{range.popFront}(&r)) {
            if(!#{contains}(other, *#{range.frontView}(&r))) return 0;
          }
          return 1;
        }
        #{define} int #{remove}(#{type}* self, const #{element.type} what) {
          assert(self);
          return #{@bucket.remove}(#{findBucket}(self, what), what);
        }
      $ if element.equality_testable?
    end
  end # HashSet


  class HashSet::Range < Range::Input

    def initialize(container, buckets, bucket)
      super(container, nil, [@bucket = bucket, @bucketsRange = buckets.range, @bucketRange = bucket.range])
    end

    def interface_declarations(stream)
      super
      stream << %$
        typedef struct {
          #{@bucketsRange.type} buckets_range;
          #{@bucketRange.type} bucket_range;
        } #{type};
      $
    end

    def interface_definitions(stream)
      super
      stream << %$
        AUTOC_EXTERN void #{_bucketFF}(#{type}* self);
        #{define} #{type}* #{create}(#{type}* self, const #{@container.type}* container) {
          assert(self);
          assert(container);
          #{@bucketsRange.create}(&self->buckets_range, &container->buckets);
          #{@bucketRange.create}(&self->bucket_range, #{@bucketsRange.frontView}(&self->buckets_range));
          #{_bucketFF}(self);
          return self;
        }
        #{define} int #{empty}(const #{type}* self) {
          assert(self);
          return #{@bucketRange.empty}(&self->bucket_range);
        }
        #{define} void #{popFront}(#{type}* self) {
          assert(!#{empty}(self));
          if(#{@bucketRange.empty}(&self->bucket_range)) {
            #{_bucketFF}(self);
          } else {
            #{@bucketRange.popFront}(&self->bucket_range);
          }
        }
        #{define} const #{@container.element.type}* #{frontView}(const #{type}* self) {
          assert(self);
          assert(!#{@bucketRange.empty}(&self->bucket_range));
          return #{@bucketRange.frontView}(&self->bucket_range);
        }
      $
      stream << %$
        #{define} #{@container.element.type} #{front}(const #{type}* self) {
          #{@container.element.type} result;
          const #{@container.element.type}* e = #{frontView}(self);
          #{@container.element.clone(:result, '*e')};
          return result;
        }
      $ if @container.element.cloneable?
    end

    def definitions(stream)
      super
      stream << %$
        /* Fast forward to the next non-empty bucket if any */
        void #{_bucketFF}(#{type}* self) {
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