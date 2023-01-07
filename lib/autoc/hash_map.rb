# frozen_string_literal: true


require 'autoc/record'
require 'autoc/hash_set'
require 'autoc/association'


module AutoC


  using STD::Coercions


  class HashMap < Association

    def range = @range ||= Range.new(self, visibility: visibility)

    def node = @node ||= Node.new(identifier(:_node, abbreviate: true), { index: index, element: element }, visibility: :internal )

    def set = @set ||= Set.new(identifier(:_set, abbreviate: true), node, visibility: :internal)

    def initialize(*args, **kws)
      super
      dependencies << node << set
    end

    def render_interface(stream)
      if public?
        stream << %{
          /**
            #{defgroup}
            @brief Hash-based unordered collection of #{index}->#{element} pairs.

            For iteration over the set elements refer to @ref #{range}.

            @see C++ [std::unordered_map<K,T>](https://en.cppreference.com/w/cpp/container/unordered_map)

            @since 2.0
          */
          /**
            #{ingroup}
            @brief Opaque structure holding state of the hash map
            @since 2.0
          */
        }
      else
        stream << PRIVATE
      end
      stream << %{
        typedef struct {
          #{set} set; /**< @private */
        } #{signature};
      }
    end
  
  end # HashMap


  class Node < Record
  end # Node


  class HashMap::Set < HashSet
    def initialize(*args, **kws)
      @omit_set_operations = true
      super
    end
  end # Set


end