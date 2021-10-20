# frozen_string_literal: true


require 'autoc/container'
require 'autoc/hash_set'


module AutoC


  class HashMap < AssociativeContainer

    def initialize(type, key, element, visibility = :public)
      super
      @node = Node.new(self, self.key, self.element)
      @set = Set.new(self, @node)
      dependencies << @node << @set
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
  end


  class HashMap::Set < HashSet
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