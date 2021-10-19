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
      @key = key
      @element = element
      dependencies << @key << @element
    end

    def composite_interface_declarations(stream)
      stream << %$
        typedef struct {
          #{@key.type} key;
          #{@element.type} element;
        } #{type};
      $
      super
    end
  end
end