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
      dependencies << (@rng = rng) << STD::MATH_H
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
          size_t size, depth; /**< @private */
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
      method(:void, :_merge, { node: _node_pp, left: _node_p, right: _node_p }, visibility: :internal).configure do
        code %{
          if(!left || !right) {
            *node = left ? left : right;
          } else if(left->priority > right->priority) {
            #{_merge.('left->right', '*left->right', '*right')};
            *node = left;
          } else {
            #{_merge.('right->left', '*left', '*right->left')};
            *node = right;
          }
        }
      end
      method(:void, :_split, { node: _node_p, index: index.const_rvalue, left: _node_pp, right: _node_pp }, visibility: :internal).configure do
        code %{
          assert(left);
          assert(right);
          if(!node) {
            *left = *right = NULL;
          } else if(#{_index.compare.(index, 'node->index')} < 0) {
            #{_split.('*node->left', index, left, 'node->left')};
            *right = node;
          } else {
            #{_split.('*node->right', index, 'node->right', right)};
            *left = node;
          }
        }
      end
      method(_node_p, :_lookup, { node: _node_p, index: index.const_rvalue }, visibility: :private).configure do
        code %{
          if(node) {
            const int c = #{_index.compare.(index, 'node->index')};
            if(!c) return node;
            else if(c < 0) return #{_lookup.('*node->left', index)};
            else return #{_lookup.('*node->right', index)};
          } else return NULL;
        }
      end
      default_create.configure do
        code %{
          #{type} t = {NULL, 0, 0};
          assert(target);
          *target = t;
        }
      end
      method(:void, :_dispose, { node: _node_p }, visibility: :internal).configure do
        code %{
          if(node) {
            #{_dispose.('*node->left')};
            #{_dispose.('*node->right')};
            #{index.destroy.('node->index') if index.destructible?};
            #{element.destroy.('node->element') if element.destructible?};
            #{memory.free(:node)};
          }
        }
      end
      destroy.configure do
        code %{
          assert(target);
          #{_dispose.('*target->root')};
        }
      end
      empty.configure do
        code %{
          assert(target);
          return target->root == NULL;
        }
      end
      size.configure do
        inline_code %{
          assert(target);
          return target->size;
        }
      end
      check.configure do
        dependencies << _lookup
        inline_code %{
          assert(target);
          return #{_lookup.('*target->root', index)} != NULL;
        }
      end
      find_first.configure do
        code %{
          /* TODO */
        }
      end
      contains.configure do
        code %{
          /* TODO */
        }
      end
      view.configure do
        code %{
          #{_node_p} node;
          assert(target);
          return (node = #{_lookup.('*target->root', index)}) ? &node->element : NULL;
        }
      end
      method(:void, :_insert, { target: rvalue, node: _node_pp, new_node: _node_p, depth: :size_t }, visibility: :internal).configure do
        code %{
          assert(node);
          assert(new_node);
          if(target->depth < depth) target->depth = depth;
          if(*node) {
            if(new_node->priority > (*node)->priority) {
              #{_split.('**node', 'new_node->index', 'new_node->left', 'new_node->right')};
              *node = new_node;
            } else {
              #{_node_p} next_node = #{index.compare.('new_node->index', '(*node)->index')} < 0 ? (*node)->left : (*node)->right;
              #{_insert.(target, 'next_node', new_node, 'depth+1')};
            }
          } else *node = new_node;
        }
      end
      set.configure do
        code %{
          int insert;
          #{_node_p} node;
          union {
            #{rng.state_type} state;
            #{_node_p} node;
          } t;
          assert(target);
          insert = (node = #{_lookup.('*target->root', index)}) == NULL;
          if(insert) {
            node = #{memory.allocate(_node)}; assert(node);
            node->left = node->right = NULL;
            t.node = node; /* reinterpret bits of the node pointer's value to yield initial state for PRNG */
            node->priority = #{rng.generate('t.state')}; /* use single cycle of PRNG to convert deterministic node address into a random priority */
            #{_insert.(target, 'target->root', '*node', 1)};
            ++target->size;
          } else {
            #{_index.destroy.('node->index') if _index.destructible?};
            #{_element.destroy.('node->element') if _element.destructible?};
          }
          #{_index.copy.('node->index', index)};
          #{_element.copy.('node->element', value)};
        }
      end
      copy.configure do
        code %{
          /* TODO */
        }
      end
      equal.configure do
        code %{
          /* TODO */
        }
      end
      compare.configure do
        code %{
          /* TODO */
        }
      end
      hash_code.configure do
        code %{
          /* TODO */
        }
      end
      
    end

  end # Treap


  class Treap::Range < BidirectionalRange

    def copyable? = false

    def initialize(*args, **kws)
      super
      dependencies << STD::STACK_ALLOCATE
    end

    def render_interface(stream)
      if public?
        render_type_description(stream)
        stream << %{
          /**
            #{ingroup}
            @brief Opaque structure holding state of the treap's range
            @since 2.1
          */
        }
      else
        stream << PRIVATE
      end
      stream << %{
        typedef struct {
          #{iterable.const_rvalue} iterable; /**< @private */
          #{iterable._node_pp} front; /**< @private */
          #{iterable._node_pp} back; /**< @private */
          int front_index, back_index; /**< @private */
        } #{signature};
      }
    end

  private

    def configure
      super
      method(self, :new_, { iterable: _iterable.const_rvalue, front_storage: _iterable._node_pp, back_storage: _iterable._node_pp }, visibility: :private).configure do
        code %{
          #{type} range;
          #{_iterable._node_p} node;
          range.iterable = iterable;
          range.front = front_storage;
          range.back = back_storage;
          range.front_index = range.back_index = -1;
          node = iterable->root;
          while(node) {
            range.front[++range.front_index] = node;
            node = node->left;
          }
          node = iterable->root;
          while(node) {
            range.back[++range.back_index] = node;
            node = node->right;
          }
          return range;
        }
      end
      new.configure do
        macro_code %{#{new_}(iterable, _AUTOC_STACK_ALLOCATE(#{_iterable._node_p}, (iterable)->depth), _AUTOC_STACK_ALLOCATE(#{_iterable._node_p}, (iterable)->depth))}
      end
      custom_create.configure do
        macro_code %{*(range) = #{new}(iterable)}
      end
      empty.configure do
        inline_code %{
          return 0;/* TODO */
        }
      end
      pop_front.configure do
        dependencies << empty
        inline_code %{
          /* TODO */
        }
      end
      pop_back.configure do
        dependencies << empty
        inline_code %{
          /* TODO */
        }
      end
      view_front.configure do
        dependencies << empty
        inline_code %{
          assert(!#{empty.(range)});
          return &range->front[range->front_index]->element;
        }
      end
      view_back.configure do
        dependencies << empty
        inline_code %{
          assert(!#{empty.(range)});
          return &range->back[range->back_index]->element;
        }
      end
    end

  end # Range

end
