require "autoc/collection"
require "autoc/collection/list"


module AutoC

  
=begin

TreeSet is a sorted container holding unique elements.

The TreeSet implements the Red-Black Tree algorithm.
The implementation is based on the code by Emin Martinian <emin@alum.mit.edu>.
http://web.mit.edu/~emin/Desktop/ref_to_emin/www.old/source_code/red_black_tree/index.html

The collection's C++ counterpart is +std::set<>+ template class.

=end
class TreeSet < Collection

  def initialize(*args)
    super
    key_requirement(element)
  end
  
  def write_intf_types(stream)
    super
    stream << %$
      /***
      **** #{type}<#{element.type}> (#{self.class})
      ***/
    $ if public?
    stream << %$
      typedef struct #{type} #{type};
      typedef struct #{node} #{node};
      typedef struct #{it} #{it};
      struct #{type} {
        #{node}* root;
        #{node}* nil;
        size_t size;
      };
      struct #{it} {
        int start, ascending;
        #{type_ref} tree;
        #{node}* node;
      };
      struct #{node} {
        int flags;
        #{node}* left;
        #{node}* right;
        #{node}* parent;
        #{element.type} element;
      };
    $
  end
  
  def write_intf_decls(stream, declare, define)
    super
    stream << %$
      #{declare} #{ctor.declaration};
      #{declare} #{dtor.declaration};
      #{declare} #{copy.declaration};
      #{declare} #{equal.declaration};
      #{declare} #{identify.declaration};
      #{declare} void #{purge}(#{type_ref});
      #{declare} int #{contains}(#{type_ref}, #{element.type});
      #{declare} #{element.type} #{get}(#{type_ref}, #{element.type});
      #{declare} size_t #{size}(#{type_ref});
      #define #{empty}(self) (#{size}(self) == 0)
      #{declare} int #{put}(#{type_ref}, #{element.type});
      #{declare} int #{replace}(#{type_ref}, #{element.type});
      #{declare} int #{remove}(#{type_ref}, #{element.type});
      #{declare} void #{exclude}(#{type_ref}, #{type_ref});
      #{declare} void #{retain}(#{type_ref}, #{type_ref});
      #{declare} void #{include}(#{type_ref}, #{type_ref});
      #{declare} void #{invert}(#{type_ref}, #{type_ref});
      #{declare} void #{itCtor}(#{it_ref}, #{type_ref});
      #define #{itCtor}(self, type) #{itCtorEx}(self, type, 1)
      #{declare} void #{itCtorEx}(#{it_ref}, #{type_ref}, int);
      #{declare} int #{itMove}(#{it_ref});
      #{declare} #{element.type} #{itGet}(#{it_ref});

    $
  end

  def write_impls(stream, define)
    super
    stream << %$
      #define #{isRed}(x) (x->flags & 1)
      #define #{setRed}(x) (x->flags |= 1)
      #define #{dropRed}(x) (x->flags &= ~1)
      #define #{copyRed}(x, y) if(#{isRed}(y)) #{setRed}(x); else #{dropRed}(x);
      #define #{isSet}(x) (x->flags & 2)
      #define #{setSet}(x) (x->flags |= 2)
      #define #{dropSet}(x) (x->flags &= ~2)
      static #{element.type_ref} #{itGetRef}(#{it_ref});
      static int #{containsAllOf}(#{type_ref} self, #{type_ref} other) {
        #{it} it;
        #{itCtor}(&it, self);
        while(#{itMove}(&it)) {
          if(!#{contains}(other, *#{itGetRef}(&it))) return 0;
        }
        return 1;
      }
      static void #{leftRotate}(#{type_ref} self, #{node}* x) {
        #{node}* y;
        #{assert}(self);
        #{assert}(x);
        y = x->right;
        x->right = y->left;
        if(y->left != self->nil) y->left->parent = x;
        y->parent = x->parent;   
        if(x == x->parent->left) {
          x->parent->left = y;
        } else {
          x->parent->right = y;
        }
        y->left = x;
        x->parent = y;
        #{assert}(!#{isRed}(self->nil));
      }
      static void #{rightRotate}(#{type_ref} self, #{node}* y) {
        #{node}* x;
        #{assert}(self);
        #{assert}(y);
        x = y->left;
        y->left = x->right;
        if(self->nil != x->right)  x->right->parent = y;
        x->parent = y->parent;
        if(y == y->parent->left) {
          y->parent->left = x;
        } else {
          y->parent->right = x;
        }
        x->right = y;
        y->parent = x;
        #{assert}(!#{isRed}(self->nil));
      }
      #define #{compare}(lt, rt) (#{element.equal(:lt, :rt)} ? 0 : (#{element.less(:lt, :rt)} ? -1 : +1))
      #{define} #{ctor.definition} {
        #{node}* temp;
        #{assert}(self);
        self->size = 0;
        temp = self->nil = (#{node}*) #{malloc}(sizeof(#{node})); #{assert}(temp);
        temp->parent = temp->left = temp->right = temp;
        #{dropRed}(temp);
        #{dropSet}(temp);
        temp = self->root = (#{node}*) #{malloc}(sizeof(#{node})); #{assert}(temp);
        temp->parent = temp->left = temp->right = self->nil;
        #{dropRed}(temp);
        #{dropSet}(temp);
      }
      static void #{nodeDtor}(#{type_ref} self, #{node}* x) {
        #{assert}(self);
        #{assert}(x);
        if(x != self->nil) {
          #{nodeDtor}(self, x->left);
          #{nodeDtor}(self, x->right);
          if(#{isSet}(x)) #{element.dtor("x->element")};
          #{free}(x);
        }
      }
      #{define} #{dtor.definition} {
        #{assert}(self);
        #{nodeDtor}(self, self->root->left);
        #{free}(self->root);
        #{free}(self->nil);
      }
      #{define} #{copy.definition} {
        #{it} it;
        #{assert}(src);
        #{assert}(dst);
        #{ctor}(dst);
        #{itCtor}(&it, src);
        while(#{itMove}(&it)) #{put}(dst, *#{itGetRef}(&it));
      }
      #{define} #{equal.definition} {
        #{assert}(lt);
        #{assert}(rt);
        return #{size}(lt) == #{size}(rt) && #{containsAllOf}(lt, rt) && #{containsAllOf}(rt, lt);
      }
      #{define} #{identify.definition} {
        #{it} it;
        size_t result = 0;
        #{assert}(self);
        #{itCtor}(&it, self);
        while(#{itMove}(&it)) {
          #{element.type}* e = #{itGetRef}(&it);
          result ^= #{element.identify("*e")};
          result = AUTOC_RCYCLE(result);
        }
        return result;
      }
      #{define} void #{purge}(#{type_ref} self) {
        #{assert}(self);
        #{dtor}(self);
        #{ctor}(self);
      }
      static #{node}* #{findNode}(#{type_ref} self, #{element.type} element) {
        /* Returns nil and not NULL when no element is found */
        #{node}* x;
        int cmp;
        #{assert}(self);
        x = self->root->left;
        if(x == self->nil) return x;
        cmp = #{compare}(x->element, element);
        while(0 != cmp) {
          if(1 == cmp) {
            x = x->left;
          } else {
            x = x->right;
          }
          if (x == self->nil) return x;
          cmp = #{compare}(x->element, element);
        }
        return x;
      }
      #{define} int #{contains}(#{type_ref} self, #{element.type} element) {
        #{assert}(self);
        return #{findNode}(self, element) == self->nil ? 0 : 1;
      }
      #{define} #{element.type} #{get}(#{type_ref} self, #{element.type} element) {
        #{node}* x;
        #{element.type} result;
        int cmp;
        #{assert}(self);
        #{assert}(#{contains}(self, element));
        x = self->root->left;
        if(x == self->nil) #{abort}();
        cmp = #{compare}(x->element, element);
        while(0 != cmp) {
          if(1 == cmp) {
            x = x->left;
          } else {
            x = x->right;
          }
          if(x == self->nil) #{abort}();
          cmp = #{compare}(x->element, element);
        }
        #{element.copy("result", "x->element")};
        return result;
      }
      #{define} size_t #{size}(#{type_ref} self) {
        #{assert}(self);
        return self->size;
      }
      static void #{insertNode}(#{type_ref} self, #{node}* z) {
        #{node}* x;
        #{node}* y;
        #{assert}(self);
        #{assert}(z);
        z->left = z->right = self->nil;
        y = self->root;
        x = self->root->left;
        while(x != self->nil) {
          y = x;
          if(1 == #{compare}(x->element, z->element)) {
            x = x->left;
          } else {
            x = x->right;
          }
        }
        z->parent = y;
        if ((y == self->root) || (1 == #{compare}(y->element, z->element))) {
          y->left = z;
        } else {
          y->right = z;
        }
        #{assert}(!#{isRed}(self->nil));
      }
      #{define} int #{put}(#{type_ref} self, #{element.type} element) {
        #{node}* x;
        #{node}* y;
        #{node}* node;
        #{assert}(self);
        /* FIXME searching for duplicate followed by insertion might be inefficient */
        if(#{contains}(self, element)) return 0;
        x = (#{node}*) #{malloc}(sizeof(#{node})); #{assert}(x);
        #{element.copy("x->element", "element")};
        #{setSet}(x);
        ++self->size;
        #{insertNode}(self, x);
        node = x;
        #{setRed}(x);
        while(#{isRed}(x->parent)) {
          if(x->parent == x->parent->parent->left) {
            y = x->parent->parent->right;
            if(#{isRed}(y)) {
              #{dropRed}(x->parent);
              #{dropRed}(y);
              #{setRed}(x->parent->parent);
              x = x->parent->parent;
            } else {
              if(x == x->parent->right) {
                x = x->parent;
                #{leftRotate}(self, x);
              }
              #{dropRed}(x->parent);
              #{setRed}(x->parent->parent);
              #{rightRotate}(self, x->parent->parent);
            } 
          } else {
            y = x->parent->parent->left;
            if(#{isRed}(y)) {
              #{dropRed}(x->parent);
              #{dropRed}(y);
              #{setRed}(x->parent->parent);
              x = x->parent->parent;
            } else {
              if(x == x->parent->left) {
                x = x->parent;
                #{rightRotate}(self, x);
              }
              #{dropRed}(x->parent);
              #{setRed}(x->parent->parent);
              #{leftRotate}(self, x->parent->parent);
            } 
          }
        }
        #{dropRed}(self->root->left);
        #{assert}(!#{isRed}(self->nil));
        #{assert}(!#{isRed}(self->root));
        return 1;
      }
      #{define} int #{replace}(#{type_ref} self, #{element.type} element) {
        int removed;
        #{assert}(self);
        /* FIXME might be inefficient */
        removed = #{remove}(self, element);
        #{put}(self, element);
        return removed;
      }
      static void #{fixupNode}(#{type_ref} self, #{node}* x) {
        #{node}* root;
        #{node}* w;
        #{assert}(self);
        #{assert}(x);
        root = self->root->left;
        while(!#{isRed}(x) && (root != x)) {
          if(x == x->parent->left) {
            w = x->parent->right;
            if(#{isRed}(w)) {
              #{dropRed}(w);
              #{setRed}(x->parent);
              #{leftRotate}(self, x->parent);
              w = x->parent->right;
            }
            if((!#{isRed}(w->right)) && (!#{isRed}(w->left))) { 
              #{setRed}(w);
              x = x->parent;
            } else {
              if(!#{isRed}(w->right)) {
                #{dropRed}(w->left);
                #{setRed}(w);
                #{rightRotate}(self, w);
                w = x->parent->right;
              }
              #{copyRed}(w, x->parent);
              #{dropRed}(x->parent);
              #{dropRed}(w->right);
              #{leftRotate}(self, x->parent);
              x = root;
            }
          } else {
            w = x->parent->left;
            if(#{isRed}(w)) {
              #{dropRed}(w);
              #{setRed}(x->parent);
              #{rightRotate}(self, x->parent);
              w = x->parent->left;
            }
            if((!#{isRed}(w->right)) && (!#{isRed}(w->left))) { 
              #{setRed}(w);
              x = x->parent;
            } else {
              if(!#{isRed}(w->left)) {
                #{dropRed}(w->right);
                #{setRed}(w);
                #{leftRotate}(self, w);
                w = x->parent->left;
              }
              #{copyRed}(w, x->parent);
              #{dropRed}(x->parent);
              #{dropRed}(w->left);
              #{rightRotate}(self, x->parent);
              x = root;
            }
          }
        }
        #{dropRed}(x);
        #{assert}(!#{isRed}(self->nil));
      }
      static #{node}* #{prevNode}(#{type_ref} self, #{node}* x) { 
        #{node}* y;
        #{assert}(self);
        #{assert}(x);
        if(self->nil != (y = x->left)) {
          while(y->right != self->nil) {
            y = y->right;
          }
          return y;
        } else {
          y = x->parent;
          while(x == y->left) { 
            if(y == self->root) return self->nil; 
            x = y;
            y = y->parent;
          }
          return y;
        }
      }
      static #{node}* #{nextNode}(#{type_ref} self, #{node}* x) { 
        #{node}* y;
        #{assert}(self);
        #{assert}(x);
        if(self->nil != (y = x->right)) {
          while(y->left != self->nil) {
            y = y->left;
          }
          return y;
        } else {
          y = x->parent;
          while(x == y->right) {
            x = y;
            y = y->parent;
          }
          if(y == self->root) return self->nil;
          return y;
        }
      }
      static void #{deleteNode}(#{type_ref} self, #{node}* z) {
        #{node}* x;
        #{node}* y;
        #{assert}(self);
        #{assert}(z);
        y = ((z->left == self->nil) || (z->right == self->nil)) ? z : #{nextNode}(self, z);
        x = (y->left == self->nil) ? y->right : y->left;
        if(self->root == (x->parent = y->parent)) {
          self->root->left = x;
        } else {
          if(y == y->parent->left) {
            y->parent->left = x;
          } else {
            y->parent->right = x;
          }
        }
        if(y != z) {
          #{assert}(y != self->nil);
          if(!#{isRed}(y)) #{fixupNode}(self, x);
          if(#{isSet}(z)) {
            #{element.dtor("z->element")};
            --self->size;
          }
          y->left = z->left;
          y->right = z->right;
          y->parent = z->parent;
          #{copyRed}(y, z);
          z->left->parent = z->right->parent = y;
          if(z == z->parent->left) {
            z->parent->left = y; 
          } else {
            z->parent->right = y;
          }
          #{free}(z);
        } else {
          if(#{isSet}(y)) {
            #{element.dtor("y->element")};
            --self->size;
          }
          if(!#{isRed}(y)) #{fixupNode}(self, x);
          #{free}(y);
        }
        #{assert}(!#{isRed}(self->nil));
      }
      #{define} int #{remove}(#{type_ref} self, #{element.type} element) {
        #{node}* x;
        #{assert}(self);
        x = #{findNode}(self, element);
        if(x == self->nil) {
          return 0;
        } else {
          #{deleteNode}(self, x);
          return 1;
        }
      }
      #{define} void #{exclude}(#{type_ref} self, #{type_ref} other) {
        #{it} it;
        #{assert}(self);
        #{assert}(other);
        #{itCtor}(&it, other);
        while(#{itMove}(&it)) #{remove}(self, *#{itGetRef}(&it));
      }
      #{define} void #{include}(#{type_ref} self, #{type_ref} other) {
        #{it} it;
        #{assert}(self);
        #{assert}(other);
        #{itCtor}(&it, other);
        while(#{itMove}(&it)) #{put}(self, *#{itGetRef}(&it));
      }
      #{define} void #{retain}(#{type_ref} self, #{type_ref} other) {
        #{it} it;
        #{type} set;
        #{assert}(self);
        #{assert}(other);
        #{ctor}(&set);
        #{itCtor}(&it, self);
        while(#{itMove}(&it)) {
          #{element.type}* e = #{itGetRef}(&it);
          if(#{contains}(other, *e)) #{put}(&set, *e);
        }
        #{dtor}(self);
        *self = set;
      }
      #{define} void #{invert}(#{type_ref} self, #{type_ref} other) {
        #{it} it;
        #{type} set;
        #{assert}(self);
        #{assert}(other);
        #{ctor}(&set);
        #{itCtor}(&it, self);
        while(#{itMove}(&it)) {
          #{element.type}* e = #{itGetRef}(&it);
          if(!#{contains}(other, *e)) #{put}(&set, *e);
        }
        #{itCtor}(&it, other);
        while(#{itMove}(&it)) {
          #{element.type}* e = #{itGetRef}(&it);
          if(!#{contains}(self, *e)) #{put}(&set, *e);
        }
        #{dtor}(self);
        *self = set;
      }
      #{define} void #{itCtorEx}(#{it_ref} self, #{type_ref} tree, int ascending) {
        #{node}* x;
        #{node}* y;
        #{assert}(self);
        #{assert}(tree);
        self->tree = tree;
        self->start = 1;
        x = tree->root;
        if(self->ascending = ascending) {
          while((y = #{prevNode}(tree, x)) != self->tree->nil) x = y;
        } else {
          while((y = #{nextNode}(tree, x)) != self->tree->nil) x = y;
        }
        self->node = (x == self->tree->root ? self->tree->nil : x);
      }
      #{define} int #{itMove}(#{it_ref} self) {
        #{assert}(self);
        if(self->start) {
          self->start = 0;
        } else {
          self->node = self->ascending ? #{nextNode}(self->tree, self->node) : #{prevNode}(self->tree, self->node);
        }
        return self->node != self->tree->nil;
      }
      #{define} #{element.type} #{itGet}(#{it_ref} self) {
        #{element.type} result;
        #{assert}(self);
        #{assert}(self->node);
        #{assert}(self->node != self->tree->nil);
        #{element.copy("result", "self->node->element")};
        return result;
      }
      static #{element.type_ref} #{itGetRef}(#{it_ref} self) {
        #{assert}(self);
        #{assert}(self->node);
        #{assert}(self->node != self->tree->nil);
        return &self->node->element;
      }
    $
  end
  
  private
  
  def key_requirement(obj)
    element_requirement(obj)
    raise "type #{obj.type} (#{obj}) must be sortable" unless obj.comparable?
  end

end # TreeSet


end # AutoC