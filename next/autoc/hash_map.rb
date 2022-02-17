# frozen_string_literal: true


require 'autoc/hash_set'
require 'autoc/map'


module AutoC


  #
  class HashMap < Map

    include Container::Hashable

    def initialize(type, key, element, visibility = :public)
      super
      @node = Node.new(self, self.key, self.element)
      @set = Set.new(self, @node)
      @range = Range.new(self, visibility)
      @create_capacity = function(self, :create_capacity, 1, { self: type, capacity: :size_t, fixed_capacity: :int }, :void)
      dependencies << range << @node << @set
    end

    def canonic_tag = "HashMap<#{key.type} -> #{element.type}>"

    def composite_interface_declarations(stream)
      stream << %$
        /**
          #{defgroup}

          @brief Hash-based unordered collection of elements of type #{element.type} mapped to unique keys of type #{key.type}

          For iteration over the map elements refer to @ref #{range.type}.

          @see C++ [std::unordered_map<K,T>](https://en.cppreference.com/w/cpp/container/unordered_map)

          @since 2.0
        */
        /**
          #{ingroup}
          @brief Opaque structure holding state of the hash map
          @since 2.0
        */
        typedef struct {
          #{@set.type} set;
        } #{type};
      $
      super
    end

    def composite_interface_definitions(stream)
      super
      stream << %$
        /**
         * @brief Create a map with specified initial capacity
         */
        #{declare(@create_capacity)};
      $
    end

    def definitions(stream)
      super
      stream << %$
        #{define(@create_capacity)} {
          #{@set.create_capacity}(&self->set, capacity, fixed_capacity);
        }
        #{define(default_create)} {
          #{create_capacity}(self, 0, 0); /* Let the underlying set choose the defaults */
        }
        #{define(destroy)} {
          #{@set.destroy}(&self->set);
        }
        #{define(@size)} {
          return #{@set.size}(&self->set);
        }
        #{define(@empty)} {
          return #{@set.empty}(&self->set);
        }
        #{define(@view)} {
          #{@node.type} node;
          node.key = key;
          return &#{@set.view}(&self->set, node)->element;
        }
        #{define(@contains)} {
          for(#{range.type} r = #{get_range}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{element.const_ptr_type} v = #{range.front_view}(&r);
            if(#{element.equal('*v', :value)}) return 1;
          }
          return 0;
        }
        #{define(@put)} {
          #{@node.type} node;
          node.key = key;
          if(!#{@set.contains}(&self->set, node)) {
            #{@key.copy('node.key', :key)};
            #{@element.copy('node.element', :value)};
            #{@set.put}(&self->set, node);
            return 1;
          } else return 0;
        }
        #{define(@force)} {
          /* FIXME get rid of code duplication */
          int replace = #{remove}(self, key);
          #{put}(self, key, value);
          return replace;
        }
        #{define(@remove)} {
          #{@node.type} node;
          node.key = key;
          return #{@set.remove}(&self->set, node);
        }
      $
    end
  end


  #
  class HashMap::Range < Range::Forward

    def initialize(*args)
      super
      @set = iterable.instance_variable_get(:@set)
    end

    def composite_interface_declarations(stream)
      stream << %$
        /**
          #{defgroup}
          @ingroup #{iterable.type}

          @brief #{canonic_desc}

          This range implements the @ref #{archetype} archetype.

          @see @ref Range

          @since 2.0
        */
        /**
          #{ingroup}
          @brief Opaque structure holding state of the map's range
          @since 2.0
        */
        typedef struct {
          #{@set.range.type} set_range; /**< @private */
        } #{type};
      $
      super
    end

    def definitions(stream)
      super
      stream << %$
        #{define(custom_create)} {
          assert(self);
          assert(iterable);
          #{@set.range.custom_create}(&self->set_range, &iterable->set);
        }
        #{define(@empty)} {
          assert(self);
          return #{@set.range.empty}(&self->set_range);
        }
        #{define(@pop_front)} {
          assert(self);
          #{@set.range.pop_front}(&self->set_range);
        }
        #{define(@front_view)} {
          assert(self);
          assert(!#{empty}(self));
          return &#{@set.range.front_view}(&self->set_range)->element;
        }
      $
    end
  end

  class HashMap::Set < BasicHashSet

    def initialize(map, element) = super(Once.new { map.decorate_identifier(:_set) }, element, :internal)

    def definitions(stream)
      super
      # Rolling out the custom set hasher to include both key and element into consideration
      # instead of using node's version which is for key searching only
      stream << %$
        #{define(hash_code)} {
          size_t hash;
          #{hasher.type} hasher;
          #{hasher.create(:hasher)};
          for(#{range.type} r = #{get_range}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{element.const_ptr_type} node_ptr = #{range.front_view}(&r);
            #{hasher.update(:hasher, element.instance_variable_get(:@key).hash_code('node_ptr->key'))};
            #{hasher.update(:hasher, element.instance_variable_get(:@element).hash_code('node_ptr->element'))};
          }
          hash = #{hasher.result(:hasher)};
          #{hasher.destroy(:hasher)};
          return hash;
        }
      $
    end
  end


  class HashMap::Node < Composite

    def initialize(map, key, element)
      super(Once.new { map.decorate_identifier(:_node) }, :internal)
      dependencies << (@key = key) << (@element = element)
    end

    def destructible? = @key.destructible? || @element.destructible?

    def copy(value, source) = "#{value} = #{source}"

    def composite_interface_declarations(stream)
      stream << %$
        typedef struct {
          #{@key.type} key;
          #{@element.type} element;
        } #{type};
      $
      super
    end

    def definitions(stream)
      super
      # Element is not considered upon hashing or equality comparison to facilitate the key search
      stream << %$
        #{define(equal)} {
          assert(self);
          assert(other);
          return #{@key.equal('self->key', 'other->key')};
        }
        #{define(hash_code)} {
          #{hasher.type} hasher;
          size_t hash;
          #{hasher.create(:hasher)};
          #{hasher.update(:hasher, @key.hash_code('self->key'))};
          hash = #{hasher.result(:hasher)};
          #{hasher.destroy(:hasher)};
          return hash;
        }
      $
      stream << %$
        #{define(destroy)} {
          #{@key.destroy('self->key') if @key.destructible?};
          #{@element.destroy('self->element') if @element.destructible?};
        }
      $ if destructible?
    end
  end
end