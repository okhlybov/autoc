# frozen_string_literal: true


require 'autoc/container'
require 'autoc/hash_set'


module AutoC


  class HashMap < AssociativeContainer

    include Container::Hashable

    def initialize(type, key, element, visibility = :public)
      super
      @node = Node.new(self, self.key, self.element)
      @set = Set.new(self, @node)
      @range = Range.new(self, visibility)
      dependencies << range << @node << @set
    end

    def canonic_tag = "HashMap<#{key.type} -> #{element.type}>"

    def composite_interface_declarations(stream)
      stream << %$
        /**
          * #{@defgroup} #{type} #{canonic_tag} :: hash-based unordered #{key.type} to #{element.type} mapping
          * @{
          */
        typedef struct {
          #{@set.type} set;
        } #{type};
      $
      super
      stream << '/** @} */'
    end

    def definitions(stream)
      super
      stream << %$
        #{define(@size)} {
          return #{@set.size}(&self->set);
        }
        #{define(@contains)} {
          for(#{range.type} r = #{get_range}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{element.const_ptr_type} v = #{range.front_view}(&r);
            if(#{element.equal('*v', :value)}) return 1;
          }
          return 0;
        }
      $
    end
  end


  class HashMap::Range < Range::Forward

    def initialize(*args)
      super
      @set = iterable.instance_variable_get(:@set)
    end

    def composite_interface_declarations(stream)
      stream << %$
        /**
         * #{@defgroup} #{type} #{canonic_tag} :: range iterator for the iterable container #{iterable.canonic_tag}
         * @{
         */
        typedef struct {
          #{@set.range.type} set_range; /**< @private */
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
      stream << %$
        #{define(equal)} {
          assert(self);
          assert(other);
          return #{@key.equal('self->key', 'other->key')} && #{@element.equal('self->element', 'other->element')};
        }
        #{define(code)} {
          #{hasher.type} hasher;
          size_t hash, key_hash = #{@key.code('self->key')}, element_hash = #{@element.code('self->element')};
          #{hasher.create(:hasher)};
          #{hasher.update(:hasher, :key_hash)};
          #{hasher.update(:hasher, :element_hash)};
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