# frozen_string_literal: true

# https://habr.com/en/articles/101818/
# http://e-maxx.ru/algo/treap
# https://algorithmica.org/ru/treap
# http://opentrains.mipt.ru/zksh/files/zksh2015/lectures/zksh_cartesian.pdf

# Trees visualizer : https://people.ksp.sk/~kuko/bak/index.html

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
      dependencies << (@rng = rng) << STD::STDIO_H
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
      method(:int, :_merge, { node: _node_pp, left: _node_p, right: _node_p, result: :int }, visibility: :internal).configure do
        code %{
          if(!left || !right) {
            *node = left ? left : right;
          } else if(left->priority > right->priority) {
            result = #{_merge}(&left->right, left->right, right, result);
            *node = left;
          } else {
            result = #{_merge}(&right->left, left, right->left, result);
            *node = right;
          }
          return result;
        }
      end
      method(:void, :_split, { node: _node_p, index: index.const_rvalue, left: _node_pp, right: _node_pp }, visibility: :internal).configure do
        code %{
          assert(left);
          assert(right);
          if(!node) {
            *left = *right = NULL;
          } else if(#{_index.compare.(index, 'node->index')} < 0) {
            #{_split}(node->left, index, left, &node->left);
            *right = node;
          } else {
            #{_split}(node->right, index, &node->right, right);
            *left = node;
          }
        }
      end
      method(_node_p, :_lookup, { node: _node_p, index: index.const_rvalue }, visibility: :private).configure do
        code %{
          while(node) {
            const int c = #{_index.compare.(index, 'node->index')};
            if(!c) return node;
            else if(c < 0) node = node->left;
            else node = node->right;
          }
          return NULL;
        }
      end
      default_create.configure do
        code %{
          #{type} t = {NULL, 0, 0};
          assert(target);
          *target = t;
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
      method(:void, :_dispose, { node: _node_p }, visibility: :internal).configure do
        code %{
          if(node) {
            #{_dispose}(node->left);
            #{_dispose}(node->right);
            #{_destroy_node}(node);
          }
        }
      end
      destroy.configure do
        code %{
          assert(target);
          #{_dispose}(target->root);
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
          return #{_lookup}(target->root, index) != NULL;
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
          return (node = #{_lookup}(target->root, index)) ? &node->element : NULL;
        }
      end
      method(:size_t, :_insert, { target: rvalue, node: _node_pp, new_node: _node_p, depth: :size_t }, visibility: :internal).configure do
        code %{
            assert(target);
            assert(node);
            assert(new_node);
            if(!*node) *node = new_node;
            else {
              #{_node_pp} next_node = #{index.compare.('new_node->index', '(*node)->index')} < 0 ? &(*node)->left : &(*node)->right;
              if(next_node) {
                return #{_insert}(target, next_node, new_node, depth + 1);
              } else {
                *next_node = new_node;
              }
            }
            return depth;
        }
      end
      method(:int, :_erase, { node: _node_pp, index: index.const_rvalue, result: :int }, visibility: :internal).configure do
        code %{
          assert(node);
          if(*node) {
            const int c = #{_index.compare.(index, '(*node)->index')};
            if(!c) {
              int result;
              #{_node_p} dead_node = *node;
              result = #{_merge}(node, (*node)->left, (*node)->right, 1);
              #{_destroy_node}(dead_node);
              return result;
            } else {
              return #{_erase}(c < 0 ? &(*node)->left : &(*node)->right, index, result);
            }
          } else return result;
        }
      end
      method(:int, :remove, { target: rvalue, index: index.const_rvalue }).configure do
        header %{
          TODO
        }
        code %{
          int remove;
          assert(target);
          if(remove = #{_erase}(&target->root, index, 0)) --target->size;
          return remove;
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
          insert = (node = #{_lookup}(target->root, index)) == NULL; /* FIXME get rid of preliminary index search run */
          if(insert) {
            size_t depth;
            /* {index->element} association is absent - add new node */
            node = #{memory.allocate(_node)}; assert(node);
            node->left = node->right = NULL;
            #{_index.copy.('node->index', index)};
            #{_element.copy.('node->element', value)};
            t.node = node; /* reinterpret bits of the node pointer's value to yield initial state for PRNG */
            node->priority = #{rng.generate('t.state')}; /* use single cycle of PRNG to convert deterministic node address into a random priority */
            depth = #{_insert}(target, &target->root, node, 1);
            if(target->depth < depth) target->depth = depth; /* maintain maximum attained tree depth for for the range buffers allocation */
            ++target->size;
          } else {
            /* {index->element} association is present - just replace the element */
            #{_element.destroy.('node->element') if _element.destructible?};
            #{_element.copy.('node->element', value)};
          }
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
      method(:void, :_write_node, { node: _node_p, f: 'FILE*' }, constraint:-> { @emit_maintenance_code }, visibility: :internal).configure do
        code %{
          /* this code assumes the index type is compatible with int */
          if(node) {
            if(node->left) {
              fprintf(f, "%d -> %d [color=blue]\\n", node->index, (int)node->left->index);
              #{_write_node}(node->left, f);
            }
            if(node->right) {
              fprintf(f, "%d -> %d [color=red]\\n", node->index, (int)node->right->index);
              #{_write_node}(node->right, f);
            }
          }
        }
      end
      method(:void, :dump_dot, { target: const_rvalue, file: 'char*'}, constraint:-> { @emit_maintenance_code }, visibility: :private).configure do
        code %{
          FILE* f = fopen(file, "wt");
          fputs("digraph {\\n", f);
          #{_write_node}(target->root, f);
          fputs("}\\n", f);
          fclose(f);
        }
      end
    end

  end # Treap


  Treap::Range = TreeRange # Range


end
