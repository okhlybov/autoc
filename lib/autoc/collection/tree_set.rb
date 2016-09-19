require "autoc/collection"
require "autoc/collection/list"


module AutoC

  
=begin

TreeSet is a sorted container holding unique elements.

The TreeSet implements the Red-Black Tree algorithm.

This code is an adaptation of the rbtree code from the http://www.nlnetlabs.nl/projects/ldns[NLNetLabs LDNS] project.

The collection's C++ counterpart is +std::set<>+ template class.

== Generated C interface

=== Collection management

[cols=2*]
|===
|*_void_* ~type~Copy(*_Type_* * +dst+, *_Type_* * +src+)
|
Create a new set +dst+ filled with the contents of +src+.
A copy operation is performed on every element in +src+.

NOTE: Previous contents of +dst+ is overwritten.

|*_void_* ~type~Ctor(*_Type_* * +self+)
|
Create a new empty set +self+.

NOTE: Previous contents of +self+ is overwritten.

|*_void_* ~type~Dtor(*_Type_* * +self+)
|
Destroy set +self+.
Stored elements are destroyed as well by calling the respective destructors.

|*_int_* ~type~Equal(*_Type_* * +lt+, *_Type_* * +rt+)
|
Return non-zero value if sets +lt+ and +rt+ are considered equal by contents and zero value otherwise.

|*_size_t_* ~type~Identify(*_Type_* * +self+)
|
Return hash code for set +self+.
|===

=== Basic operations

[cols=2*]
|===
|*_int_* ~type~Contains(*_Type_* * +self+, *_E_* +what+)
|
Return non-zero value if set +self+ contains an element considered equal to the element +what+ and zero value otherwise.

|*_int_* ~type~Empty(*_Type_* * +self+)
|
Return non-zero value if set +self+ contains no elements and zero value otherwise.

|*_E_* ~type~Get(*_Type_* * +self+, *_E_* +what+)
|
Return a _copy_ of the element in +self+ considered equal to the element +what+.

WARNING: +self+ *must* contain such element otherwise the behavior is undefined. See ~type~Contains().

|*_E_* ~type~PeekLowest(*_Type_* * +self+)
|
Return a _copy_ of the lowest element in +self+.

WARNING: +self+ *must not* be empty otherwise the behavior is undefined. See ~type~Empty().

|*_E_* ~type~PeekHighest(*_Type_* * +self+)
|
Return a _copy_ of the highest element in +self+.

WARNING: +self+ *must not* be empty otherwise the behavior is undefined. See ~type~Empty().

|*_void_* ~type~Purge(*_Type_* * +self+)
|
Remove and destroy all elements stored in +self+.

|*_int_* ~type~Put(*_Type_* * +self+, *_E_* +what+)
|
Put a _copy_ of the element +what+ into +self+ *only if* there is no such element in +self+ which is considered equal to +what+.

Return non-zero value on successful element put (that is there was not such element in +self+) and zero value otherwise.

|*_int_* ~type~Replace(*_Type_* * +self+, *_E_* +with+)
|
If +self+ contains an element which is considered equal to the element +with+,
replace that element with a _copy_ of +with+, otherwise do nothing.
Replaced element is destroyed.

Return non-zero value if the replacement was actually performed and zero value otherwise.

|*_int_* ~type~Remove(*_Type_* * +self+, *_E_* +what+)
|
Remove and destroy an element in +self+ which is considered equal to the element +what+.

Return non-zero value on successful element removal and zero value otherwise.

|*_size_t_* ~type~Size(*_Type_* * +self+)
|
Return number of elements stored in +self+.
|===

=== Logical operations

[cols=2*]
|===
|*_void_* ~type~Exclude(*_Type_* * +self+, *_Type_* * +other+)
|
Perform the difference operation that is +self+ will retain only the elements not contained in +other+.

Removed elements are destroyed.
|*_void_* ~type~Include(*_Type_* * +self+, *_Type_* * +other+)
|
Perform the union operation that is +self+ will contain the elements from both +self+ and +other+.

+self+ receives the _copies_ of extra elements in +other+.

|*_void_* ~type~Invert(*_Type_* * +self+, *_Type_* * +other+)
|
Perform the symmetric difference operation that is +self+ will retain the elements contained in either +self+ or +other+, but not in both.

Removed elements are destroyed, extra elements are _copied_.

|*_void_* ~type~Retain(*_Type_* * +self+, *_Type_* * +other+)
|
Perform the intersection operation that is +self+ will retain only the elements contained in both +self+ and +other+.

Removed elements are destroyed.
|===

=== Iteration

[cols=2*]
|===
|*_void_* ~it~Ctor(*_IteratorType_* * +it+, *_Type_* * +self+)
|
Create a new ascending iterator +it+ on tree +self+. See ~it~CtorEx().

NOTE: Previous contents of +it+ is overwritten.

|*_void_* ~it~CtorEx(*_IteratorType_* * +it+, *_Type_* * +self+, *_int_* +ascending+)
|
Create a new iterator +it+ on tree +self+.
Non-zero value of +ascending+ specifies an ascending (+lowest to highest element traversal+) iterator, zero value specifies a descending (+highest to lowest element traversal+) iterator.

NOTE: Previous contents of +it+ is overwritten.

|*_int_* ~it~Move(*_IteratorType_* * +it+)
|
Advance iterator position of +it+ *and* return non-zero value if new position is valid and zero value otherwise.

|*_E_* ~it~Get(*_IteratorType_* * +it+)
|
Return a _copy_ of current element pointed to by the iterator +it+.

WARNING: current position *must* be valid otherwise the behavior is undefined. See ~it~Move().
|===

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
        size_t size;
      };
      struct #{it} {
        int start, ascending;
        #{node}* node;
      };
      struct #{node} {
        int color;
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
      #{declare} #{element.type} #{peekLowest}(#{type_ref});
      #{declare} #{element.type} #{peekHighest}(#{type_ref});
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
      #define #{isRed}(x) (x->color)
      #define #{isBlack}(x) !#{isRed}(x)
      #define #{setRed}(x) (x->color = 1)
      #define #{setBlack}(x) (x->color = 0)
      #define #{compare}(lt, rt) (#{element.equal(:lt, :rt)} ? 0 : (#{element.less(:lt, :rt)} ? -1 : +1))
      static #{node} #{nullNode} = {0, NULL, NULL, NULL};
      static #{node}* #{null} = &#{nullNode};
      static #{element.type_ref} #{itGetRef}(#{it_ref});
      static int #{containsAllOf}(#{type_ref} self, #{type_ref} other) {
        #{it} it;
        #{itCtor}(&it, self);
        while(#{itMove}(&it)) {
          if(!#{contains}(other, *#{itGetRef}(&it))) return 0;
        }
        return 1;
      }
      static void #{destroyNode}(#{node}* node) {
        #{assert}(node);
        #{assert}(node != #{null});
        #{element.dtor("node->element")};
        #{free}(node);
      }
      #{define} #{ctor.definition} {
        #{assert}(self);
        self->size = 0;
        self->root = #{null};
      }
      static void #{destroy}(#{node}* node) {
        if(node != #{null}) {
          #{destroy}(node->left);
          #{destroy}(node->right);
          #{destroyNode}(node);
        }
      }
      #{define} #{dtor.definition} {
        #{assert}(self);
        #{destroy}(self->root); /* FIXME recursive algorithm might be inefficient */
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
      static void #{rotateLeft}(#{type}* self, #{node}* node) {
        #{node}* right = node->right;
        node->right = right->left;
        if(right->left != #{null}) right->left->parent = node;
        right->parent = node->parent;
        if(node->parent != #{null}) {
          if(node == node->parent->left) {
            node->parent->left = right;
          } else {
            node->parent->right = right;
          }
        } else {
          self->root = right;
        }
        right->left = node;
        node->parent = right;
      }
      static void #{rotateRight}(#{type}* self, #{node}* node) {
        #{node}* left = node->left;
        node->left = left->right;
        if(left->right != #{null}) left->right->parent = node;
        left->parent = node->parent;
        if(node->parent != #{null}) {
          if(node == node->parent->right) {
            node->parent->right = left;
          } else {
            node->parent->left = left;
          }
        } else {
          self->root = left;
        }
        left->right = node;
        node->parent = left;
      }
      static void #{insertFixup}(#{type}* self, #{node}* node) {
        #{node}* uncle;
        while(node != self->root && #{isRed}(node->parent)) {
          if(node->parent == node->parent->parent->left) {
            uncle = node->parent->parent->right;
            if(#{isRed}(uncle)) {
              #{setBlack}(node->parent);
              #{setBlack}(uncle);
              #{setRed}(node->parent->parent);
              node = node->parent->parent;
            } else {
              if(node == node->parent->right) {
                node = node->parent;
                #{rotateLeft}(self, node);
              }
              #{setBlack}(node->parent);
              #{setRed}(node->parent->parent);
              #{rotateRight}(self, node->parent->parent);
            }
          } else {
            uncle = node->parent->parent->left;
            if(#{isRed}(uncle)) {
              #{setBlack}(node->parent);
              #{setBlack}(uncle);
              #{setRed}(node->parent->parent);
              node = node->parent->parent;
            } else {
              if(node == node->parent->left) {
                node = node->parent;
                #{rotateRight}(self, node);
              }
              #{setBlack}(node->parent);
              #{setRed}(node->parent->parent);
              #{rotateLeft}(self, node->parent->parent);
            }
          }
        }
        #{setBlack}(self->root);
      }
      static void #{deleteFixup}(#{type}* self, #{node}* child, #{node}* child_parent) {
        #{node}* sibling;
        int go_up = 1;
        if(child_parent->right == child) sibling = child_parent->left; else sibling = child_parent->right;
        while(go_up) {
          if(child_parent == #{null}) return;
          if(#{isRed}(sibling)) {
            #{setRed}(child_parent);
            #{setBlack}(sibling);
            if(child_parent->right == child) #{rotateRight}(self, child_parent); else #{rotateLeft}(self, child_parent);
            if(child_parent->right == child) sibling = child_parent->left; else sibling = child_parent->right;
          }
          if(#{isBlack}(child_parent) && #{isBlack}(sibling) && #{isBlack}(sibling->left) && #{isBlack}(sibling->right)) {
            if(sibling != #{null}) #{setRed}(sibling);
            child = child_parent;
            child_parent = child_parent->parent;
            if(child_parent->right == child) sibling = child_parent->left; else sibling = child_parent->right;
          } else go_up = 0;
        }
        if(#{isRed}(child_parent) && #{isBlack}(sibling) && #{isBlack}(sibling->left) && #{isBlack}(sibling->right)) {
          if(sibling != #{null}) #{setRed}(sibling);
          #{setBlack}(child_parent);
          return;
        }
        if(child_parent->right == child && #{isBlack}(sibling) && #{isRed}(sibling->right) && #{isBlack}(sibling->left)) {
          #{setRed}(sibling);
          #{setBlack}(sibling->right);
          #{rotateLeft}(self, sibling);
          if(child_parent->right == child) sibling = child_parent->left; else sibling = child_parent->right;
        } else if(child_parent->left == child && #{isBlack}(sibling) && #{isRed}(sibling->left) && #{isBlack}(sibling->right)) {
          #{setRed}(sibling);
          #{setBlack}(sibling->left);
          #{rotateRight}(self, sibling);
          if(child_parent->right == child) sibling = child_parent->left; else sibling = child_parent->right;
        }
        sibling->color = child_parent->color;
        #{setBlack}(child_parent);
        if(child_parent->right == child) {
          #{setBlack}(sibling->left);
          #{rotateRight}(self, child_parent);
        } else {
          #{setBlack}(sibling->right);
          #{rotateLeft}(self, child_parent);
        }
      }
      static #{node}* #{findNode}(#{type_ref} self, #{element.type} element) {
        int r;
        #{node}* node;
        #{assert}(self);
        node = self->root;
        while(node != #{null}) {
          if((r = #{compare}(element, node->element)) == 0) {
            return node;
          }
          if(r < 0) {
            node = node->left;
          } else {
            node = node->right;
          }
        }
        return NULL;
      }
      #{define} int #{contains}(#{type_ref} self, #{element.type} element) {
        #{assert}(self);
        return #{findNode}(self, element) != NULL;
      }
      #{define} #{element.type} #{get}(#{type_ref} self, #{element.type} element) {
        #{node} *node;
        #{element.type} result;
        #{assert}(self);
        #{assert}(#{contains}(self, element));
        node = #{findNode}(self, element);
        #{element.copy("result", "node->element")}; /* Here we rely on NULL pointer dereference to manifest the failure! */
        return result;
      }
      #{define} size_t #{size}(#{type_ref} self) {
        #{assert}(self);
        return self->size;
      }
      #{define} int #{put}(#{type_ref} self, #{element.type} element) {
        int r;
        #{node}* data;
        #{node}* node;
        #{node}* parent;
        #{assert}(self);
        node = self->root;
        parent = #{null};
        while(node != #{null}) {
          if((r = #{compare}(element, node->element)) == 0) {
            return 0;
          }
          parent = node;
          if (r < 0) {
            node = node->left;
          } else {
            node = node->right;
          }
        }
        data = #{malloc}(sizeof(#{node})); #{assert}(data);
        #{element.copy("data->element", "element")};
        data->parent = parent;
        data->left = data->right = #{null};
        #{setRed}(data);
        ++self->size;
        if(parent != #{null}) {
          if(r < 0) {
            parent->left = data;
          } else {
            parent->right = data;
          }
        } else {
          self->root = data;
        }
        #{insertFixup}(self, data);
        return 1;
      }
      #{define} int #{replace}(#{type_ref} self, #{element.type} element) {
        int removed;
        #{assert}(self);
        /* FIXME removing followed by putting might be inefficient */
        if((removed = #{remove}(self, element))) #{put}(self, element);
        return removed;
      }
      static void #{swapColors}(#{node}* x, #{node}* y) {
        int t = x->color;
        #{assert}(x);
        #{assert}(y);
        x->color = y->color;
        y->color = t;
      }
      static void #{swapNodes}(#{node}** x, #{node}** y) {
        #{node}* t = *x; *x = *y; *y = t; 
      }
      static void #{changeParent}(#{type}* self, #{node}* parent, #{node}* old_node, #{node}* new_node) {
        if(parent == #{null}) {
          if(self->root == old_node) self->root = new_node;
          return;
        }
        if(parent->left == old_node) parent->left = new_node;
        if(parent->right == old_node) parent->right = new_node;
      }
      static void #{changeChild}(#{node}* child, #{node}* old_node, #{node}* new_node) {
        if(child == #{null}) return;
        if(child->parent == old_node) child->parent = new_node;
      }
      int #{remove}(#{type}* self, #{element.type} element) {
        #{node}* to_delete;
        #{node}* child;
        #{assert}(self);
        if((to_delete = #{findNode}(self, element)) == NULL) return 0;
        if(to_delete->left != #{null} && to_delete->right != #{null}) {
          #{node} *smright = to_delete->right;
          while(smright->left != #{null}) smright = smright->left;
          #{swapColors}(to_delete, smright);
          #{changeParent}(self, to_delete->parent, to_delete, smright);
          if(to_delete->right != smright) #{changeParent}(self, smright->parent, smright, to_delete);
          #{changeChild}(smright->left, smright, to_delete);
          #{changeChild}(smright->left, smright, to_delete);
          #{changeChild}(smright->right, smright, to_delete);
          #{changeChild}(smright->right, smright, to_delete);
          #{changeChild}(to_delete->left, to_delete, smright);
          if(to_delete->right != smright) #{changeChild}(to_delete->right, to_delete, smright);
          if(to_delete->right == smright) {
            to_delete->right = to_delete;
            smright->parent = smright;
          }
          #{swapNodes}(&to_delete->parent, &smright->parent);
          #{swapNodes}(&to_delete->left, &smright->left);
          #{swapNodes}(&to_delete->right, &smright->right);
        }
        if(to_delete->left != #{null}) child = to_delete->left; else child = to_delete->right;
        #{changeParent}(self, to_delete->parent, to_delete, child);
        #{changeChild}(child, to_delete, to_delete->parent);
        if(#{isRed}(to_delete)) {} else if(#{isRed}(child)) {
          if(child != #{null}) #{setBlack}(child);
        } else #{deleteFixup}(self, child, to_delete->parent);
        #{destroyNode}(to_delete);
        --self->size;
        return 1;
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
      static #{node}* #{lowestNode}(#{type}* self) {
        #{node} *node;
        #{assert}(self);
        node = self->root;
        if(self->root != #{null}) {
          for(node = self->root; node->left != #{null}; node = node->left);
        }
        return node;
      }
      static #{node}* #{highestNode}(#{type}* self) {
        #{node} *node;
        #{assert}(self);
        node = self->root;
        if(self->root != #{null}) {
          for(node = self->root; node->right != #{null}; node = node->right);
        }
        return node;
      }
      static #{node}* #{nextNode}(#{node}* node) {
        #{node} *parent;
        #{assert}(node);
        if(node->right != #{null}) {
          for(node = node->right;
            node->left != #{null};
            node = node->left);
        } else {
          parent = node->parent;
          while(parent != #{null} && node == parent->right) {
            node = parent;
            parent = parent->parent;
          }
          node = parent;
        }
        return node;
      }
      static #{node}* #{prevNode}(#{node}* node) {
        #{node} *parent;
        #{assert}(node);
        if(node->left != #{null}) {
          for(node = node->left;
            node->right != #{null};
            node = node->right);
        } else {
          parent = node->parent;
          while(parent != #{null} && node == parent->left) {
            node = parent;
            parent = parent->parent;
          }
          node = parent;
        }
        return node;
      }
      #{define} #{element.type} #{peekLowest}(#{type_ref} self) {
        #{node}* node;
        #{element.type} result;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        node = #{lowestNode}(self);
        #{assert}(node);
        #{assert}(node != #{null});
        #{element.copy("result", "node->element")};
        return result;
      }
      #{define} #{element.type} #{peekHighest}(#{type_ref} self) {
        #{node}* node;
        #{element.type} result;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        node = #{highestNode}(self);
        #{assert}(node);
        #{assert}(node != #{null});
        #{element.copy("result", "node->element")};
        return result;
      }
      #{define} void #{itCtorEx}(#{it_ref} self, #{type_ref} tree, int ascending) {
        #{assert}(self);
        #{assert}(tree);
        self->node = (self->ascending = ascending) ? #{lowestNode}(tree) : #{highestNode}(tree);
        self->start = 1;
      }
      #{define} int #{itMove}(#{it_ref} self) {
        #{assert}(self);
        if(self->start) {
          self->start = 0;
        } else {
          self->node = self->ascending ? #{nextNode}(self->node) : #{prevNode}(self->node);
        }
        return self->node != #{null};
      }
      static #{element.type_ref} #{itGetRef}(#{it_ref} self) {
        #{assert}(self);
        #{assert}(self->node);
        #{assert}(self->node != #{null});
        return &self->node->element;
      }
      #{define} #{element.type} #{itGet}(#{it_ref} self) {
        #{element.type} result;
        #{assert}(self);
        #{element.copy("result", "*#{itGetRef}(self)")};
        return result;
      }
    $
  end
  
  private
  
  def key_requirement(obj)
    element_requirement(obj)
    raise "type #{obj.type} (#{obj}) must be sortable" unless obj.sortable?
  end

end # TreeSet

end # AutoC