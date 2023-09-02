# frozen_string_literal: true

# https://habr.com/en/articles/101818/
# http://e-maxx.ru/algo/treap

require 'autoc/std'
require 'autoc/ranges'
require 'autoc/randoms'
require 'autoc/association'


module AutoC


  using STD::Coercions


  # Generator for treap (binary tree family) data structure
  class Treap < Association

    def _range_class = Range

    def range = @range ||= _range_class.new(self, visibility: visibility)

    attr_reader :rng

    attr_reader :_node, :_node_p, :_node_pp

    def initialize(*args, rng: Random.generator, **opts)
      super(*args, **opts)
      @_node = identifier(:_node, abbreviate: true)
      @_node_p = _node.lvalue
      @_node_pp = "#{_node}*".lvalue
      dependencies << (@rng = rng)
    end

    def render_interface(stream)
      stream << %{
        /** @private */
        typedef struct #{_node} #{_node};
      }
      if public?
        stream << %{
          /**
            #{defgroup}
            
            @brief Ordered collection of elements of type #{element} associated with unique index of type #{index}.

            For iteration over the set elements refer to @ref #{range}.

            @see https://en.wikipedia.org/wiki/Treap

            @since 2.1
          */
          /**
            #{ingroup}
            @brief Opaque structure holding state of the hash map
            @since 2.1
          */
        }
      else
        stream << PRIVATE
      end
      stream << %{
        typedef struct {
          #{_node_p} root; /**< @private */
        } #{signature};
        /** @private */
        struct #{_node} {
          #{element} element;
          #{index} index;
          #{_node_p} left;
          #{_node_p} right;
          autoc_random_t priority;
        };
      }
    end
  
  private

    alias _index index
    alias _element element

    def configure
      super
      method(_node_p, :_create_node, { index: index.const_rvalue, element: element.const_rvalue, priority: rng.type.const_rvalue, left: _node_p, right: _node_p }, constraint:-> { index.copyable? && element.copyable? }, visibility: :internal).configure do
        code %{
          #{_node_p} node = #{memory.allocate(_node)}; assert(node);
          #{_index.copy.('node->index', index)};
          #{_element.copy.('node->element', element)};
          node->left = left;
          node->right = right;
          node->priority = priority;
          //node->priority = #{rng.generate("*(#{rng.state_type}*)node")}; /* use single cycle of PRNG to convert deterministic node address into a random priority */
          return node;
        }
      end
      method(:void, :_destroy_node, { node: _node_p }, visibility: :internal).configure do
        code %{
          assert(node);
          #{index.destroy.('node->index') if index.destructible?};
          #{element.destroy.('node->element') if element.destructible?};
          #{memory.free(:node)};
        }
      end
      method(_node_p, :_merge, { left: _node_p, right: _node_p }, visibility: :internal).configure do
        code %{
          assert(left || right);
          if(!left) return right;
          if(!right) return left;
          if(left->priority > right->priority) {
            #{_node_p} new_right = #{_merge.('*left->right', '*right')};
            return #{_create_node.('left->index', 'left->element', 'left->priority', '*left->left', '*new_right')};
          } else {
            #{_node_p} new_left = #{_merge.('*left', '*right->left')};
            return #{_create_node.('right->index', 'right->element', 'right->priority', '*new_left', '*right->right')};
          }
        }
      end
      method(:void, :_split, { node: _node_p, index: index.const_rvalue, out_left: _node_pp, out_right: _node_pp }, constraint:-> { index.comparable? },  visibility: :internal).configure do
        code %{
          #{_node_p} new_node = NULL;
          assert(node);
          assert(out_left);
          assert(out_right);
          if(#{_index.compare.('node->index', index)} > 0) {
            if(!node->left) {
              *out_left = NULL;
            } else {
              #{_split.('*node->left', index, out_left, 'new_node')};
              *out_right = #{_create_node.('node->index', 'node->element', 'node->priority', '*new_node', '*node->right')};
            }
          } else {
            if(!node->right) {
              *out_right = NULL;
            } else {
              #{_split.('*node->right', index, 'new_node', out_right)};
              *out_left = #{_create_node.('node->index', 'node->element', 'node->priority', '*node->left', '*new_node')};
            }
          }
        }
      end
      default_create.configure do
        code %{
          assert(target);
          target->root = NULL;
        }
      end
      destroy.configure do
        code %{
          // TODO
        }
      end
      empty.configure do
        code %{
          // TODO
        }
      end
      size.configure do
        code %{
          // TODO
        }
      end
      check.configure do
        code %{
          // TODO
        }
      end
      find_first.configure do
        code %{
          // TODO
        }
      end
      contains.configure do
        code %{
          // TODO
        }
      end
      view.configure do
        code %{
          // TODO
        }
      end
      set.configure do
        code %{
          // TODO
        }
      end
      copy.configure do
        code %{
          // TODO
        }
      end
      equal.configure do
        code %{
          // TODO
        }
      end
      compare.configure do
        code %{
          // TODO
        }
      end
      hash_code.configure do
        code %{
          // TODO
        }
      end
      
    end

  end # Treap

  
  class Treap::Range < ForwardRange

    def render_interface(stream)
      if public?
        render_type_description(stream)
        stream << %{
          /**
            #{ingroup}
            @brief Opaque structure holding state of the list's range
            @since 2.0
          */
        }
      else
        stream << PRIVATE
      end
      stream << %{
        typedef struct {
          //#{iterable._node_p} front; /**< @private */
        } #{signature};
      }
    end

  private

    def configure
      super
      custom_create.configure do
        inline_code %{
          // TODO
        }
      end
      empty.configure do
        inline_code %{
          // TODO
        }
      end
      pop_front.configure do
        dependencies << empty
        inline_code %{
          // TODO
        }
      end
      view_front.configure do
        dependencies << empty
        inline_code %{
          // TODO
        }
      end
    end

  end # Range

end
