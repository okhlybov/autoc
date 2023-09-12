# frozen_string_literal: true

# https://habr.com/en/articles/101818/
# http://e-maxx.ru/algo/treap
# https://algorithmica.org/ru/treap

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
      dependencies << (@rng = rng) << STD::MATH_H << STD::STDIO_H
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
      method(_node_p, :_merge2, { left: _node_p, right: _node_p, depth: :size_t.lvalue }, visibility: :internal).configure do
        code %{
          if(!left) return right; else if(!right) return left;
          ++(*depth);
          if(left->priority > right->priority) {
            left->right = #{_merge2}(left->right, right, depth);
            return left;
          } else {
            right->left = #{_merge2}(left, right->left, depth);
            return right;
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
      method(:void, :_split2, { node: _node_p, index: index.const_rvalue, left: _node_pp, right: _node_pp }, visibility: :internal).configure do
        code %{
          #{_node_p} l;
          #{_node_p} r;
          assert(left);
          assert(right);
          if(!node) {
            *left = *right = NULL;
          } else if(#{_index.compare.(index, 'node->index')} < 0) {
            #{_split2}(node->right, index, &l, &r);
            node->right = l;
            *left = node;
            *right = r;
          } else {
            #{_split2}(node->left, index, &l, &r);
            node->left = r;
            *left = l;
            *right = node;
          }
        }
      end
      method(_node_p, :_lookup, { node: _node_p, index: index.const_rvalue }, visibility: :private).configure do
        code %{
          /* FIXME get rid of recursion */
          if(node) {
            const int c = #{_index.compare.('node->index', index)};
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
      method(:void , :_insert2, { target: rvalue, new_node: _node_p }, visibility: :internal).configure do
        code %{
          #{_node_p} l;
          #{_node_p} r;
          #{_node_p} rr;
          size_t ld = 1, rd = 1;
          assert(target);
          #{_split2}(target->root, new_node->index, &l, &r);
          target->root = #{_merge2}(l, #{_merge2}(new_node, r, &rd), &ld);
          target->depth = ld < rd ? rd : ld;
        }
      end
      method(:void, :_insert, { target: rvalue, node: _node_pp, new_node: _node_p, depth: :size_t }, visibility: :internal).configure do
        code %{
#if 0
          /* FIXME treap balancing insertion does not work properly and is thus disabled */
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
#else
            assert(node);
            assert(new_node);
            if(target->depth < depth) target->depth = depth;
            if(!(*node)) *node = new_node;
            else {
              #{_node_pp} next_node = #{index.compare.('new_node->index', '(*node)->index')} < 0 ? &(*node)->left : &(*node)->right;
              if(next_node) {
                #{_insert.(target, '*next_node', new_node, 'depth+1')};
              } else {
                *next_node = new_node;
              }
            }
#endif
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
            #{_index.copy.('node->index', index)};
            #{_element.copy.('node->element', value)};
            t.node = node; /* reinterpret bits of the node pointer's value to yield initial state for PRNG */
            node->priority = #{rng.generate('t.state')}; /* use single cycle of PRNG to convert deterministic node address into a random priority */
            #{_insert2}(target, node);
            //#{_insert.(target, 'target->root', '*node', 1)};
            ++target->size;
          } else {
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
      method(:void, :_write_node, { node: _node_p, f: 'FILE*' }, visibility: :internal).configure do
        code %{
          if(node) {
            if(node->left) {
              fprintf(f, "%d -> %d [color=blue]\\n", node->index, node->left->index);
              #{_write_node}(node->left, f);
            }
            if(node->right) {
              fprintf(f, "%d -> %d [color=red]\\n", node->index, node->right->index);
              #{_write_node}(node->right, f);
            }
          }
        }
      end
      method(:void, :dump_dot, { target: const_rvalue, file: 'char*'}, visibility: :private).configure do
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
          #{iterable._node_pp} fronts; /**< @private */
          #{iterable._node_pp} backs; /**< @private */
          int front, back, front_ascend, back_ascend; /**< @private */
        } #{signature};
      }
    end

  private

    def configure
      super
      method(self, :new_, { iterable: _iterable.const_rvalue, front_storage: _iterable._node_pp, back_storage: _iterable._node_pp }, visibility: :private).configure do
        code %{
          #{type} range;
          #{_iterable._node_p} next;
          range.iterable = iterable;
          range.fronts = front_storage;
          range.backs = back_storage;
          range.front = range.back = -1;
          if(iterable->root) {
            next = iterable->root;
            while(next) {
              range.fronts[++range.front] = next;
              next = next->left;
            }
            next = iterable->root;
            while(next) {
              range.backs[++range.back] = next;
              next = next->right;
            }
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
          assert(range);
          return range->front < 0 || range->back < 0;
        }
      end
      pop_front.configure do
        dependencies << empty
        inline_code %{
          #{_iterable._node_p} next;
          assert(!#{empty.(range)});
          if(range->fronts[range->front] == range->backs[range->back]) range->front = -1;
          if(range->front < 0) return;
          next = range->fronts[range->front];
          if(next->right) {
            --range->front;
            next = next->right;
            while(next) {
              range->fronts[++range->front] = next;
              next = next->left;
            }
          } else --range->front;
        }
      end
      pop_back.configure do
        dependencies << empty
        inline_code %{
          #{_iterable._node_p} next;
          assert(!#{empty.(range)});
          if(range->fronts[range->front] == range->backs[range->back]) range->back = -1;
          if(range->back < 0) return;
          next = range->backs[range->back];
          if(next->left) {
            --range->back;
            next = next->left;
            while(next) {
              range->backs[++range->back] = next;
              next = next->right;
            }
          } else --range->back;
        }
      end
      view_front.configure do
        dependencies << empty
        inline_code %{
          assert(!#{empty.(range)});
          return &range->fronts[range->front]->element;
        }
      end
      view_back.configure do
        dependencies << empty
        inline_code %{
          assert(!#{empty.(range)});
          return &range->backs[range->back]->element;
        }
      end
      method(iterable.index.const_lvalue, :view_index_front, { range: const_rvalue }).configure do
        inline_code %{
          assert(!#{empty.(range)});
          return &range->fronts[range->front]->index;
        }
      end
      method(iterable.index.const_lvalue, :view_index_back, { range: const_rvalue }).configure do
        inline_code %{
          assert(!#{empty.(range)});
          return &range->backs[range->back]->index;
        }
      end
    end

  end # Range

end
