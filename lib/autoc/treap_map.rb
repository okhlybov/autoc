# frozen_string_literal: true


require 'autoc/std'
require 'autoc/ranges'
require 'autoc/randoms'
require 'autoc/association'


module AutoC


  using STD::Coercions


  # Generator for treap (binary tree family) map data structure
  class TreapMap < Association

    def orderable? = false

    def _range_class = Range

    def range = @range ||= _range_class.new(self, visibility: visibility)

    attr_reader :rng

    attr_reader :_node, :_node_p, :_node_pp

    def initialize(*args, rng: Random.generator, **opts)
      super(*args, **opts)
      @_node = decorate(:_node, abbreviate: true)
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
            
            @brief Ordered collection of elements of type #{element} associated with unique index of type #{index}

            For iteration over the index & elements refer to @ref #{range}.

            @see https://en.wikipedia.org/wiki/Treap

            @since 2.1
          */
          /**
            #{ingroup}
            @brief Opaque structure holding state of the map
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
            int c = #{_index.compare.(index, 'node->index')};
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
        inline_code %{
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
          #{range} r;
          assert(target);
          for(r = #{range.new}(target); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{element.const_lvalue} e = #{range.view_front}(&r);
            if(#{element.equal.(value, '*e')}) return e;
          }
          return NULL;
        }
      end
      contains.configure do
        dependencies << find_first
        inline_code %{
          assert(target);
          return #{find_first}(target, value) != NULL;
        }
      end
      view.configure do
        dependencies << _lookup
        inline_code %{
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
            int c = #{_index.compare.(index, '(*node)->index')};
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
          if((remove = #{_erase}(&target->root, index, 0))) --target->size;
          return remove;
        }
      end
      set.configure do
        code %{
          int insert;
          #{_node_p} node;
          union {
            #{rng.state_type} state;
            #{_node_p} pointer;
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
            t.pointer = node; /* reinterpret bits of the node pointer's value to yield initial state for PRNG */
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
          /* FIXME ordered insertion optimizations */
          #{range} r;
          assert(target);
          assert(source);
          #{default_create}(target);
          for(r = #{range.new}(source); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{index.const_lvalue} i = #{range.view_index_front}(&r);
            #{element.const_lvalue} e = #{range.view_front}(&r);
            #{set.(target, '*i', '*e')};
          }
        }
      end
      equal.configure do
        code %{
          assert(left);
          assert(right);
          if(#{size}(left) == #{size}(right)) {
            #{range} lt, rt;
            for(lt = #{range.new}(left), rt = #{range.new}(right); !#{range.empty}(&lt) && !#{range.empty}(&rt); #{range.pop_front}(&lt), #{range.pop_front}(&rt)) {
              #{index.const_lvalue} li = #{range.view_index_front}(&lt);
              #{index.const_lvalue} ri = #{range.view_index_front}(&rt);
              #{element.const_lvalue} le = #{range.view_front}(&lt);
              #{element.const_lvalue} re = #{range.view_front}(&rt);
              if(!#{index.equal.('*li', '*ri')} || !#{element.equal.('*le', '*re')}) return 0;
            }
            return 1;
          } else return 0;
        }
      end
      hash_code.configure do
        code %{
          #{range} r;
          #{hasher.to_s} hash;
          size_t result;
          assert(target);
          #{hasher.create(:hash)};
          for(r = #{range.new}(target); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{index.const_lvalue} i = #{range.view_index_front.(:r)};
            #{element.const_lvalue} e = #{range.view_front.(:r)};
            #{hasher.update(:hash, index.hash_code.('*i'))};
            #{hasher.update(:hash, element.hash_code.('*e'))};
          }
          result = #{hasher.result(:hash)};
          #{hasher.destroy(:hash)};
          return result;
        }
      end
    end

  end # TreapMap


  TreapMap::Range = TreeMapRange # Range


end