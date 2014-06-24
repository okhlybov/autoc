require "autoc/collection"


module AutoC
  

=begin

List is an ordered unidirectional sequence container.
List supports submission/polling operations at one end hence it can be used as a LIFO container.

The collection's C++ counterpart is +std::forward_list<>+ template class.

== Generated C interface

=== Collection management

[cols=2*]
|===
|*_void_* ~type~Copy(*_Type_* * +dst+, *_Type_* * +src+)
|
Create a new list +dst+ filled with the contents of +src+.
A copy operation is performed on every element in +src+.

NOTE: Previous contents of +dst+ is overwritten.

|*_void_* ~type~Ctor(*_Type_* * +self+)
|
Create a new empty list +self+.

NOTE: Previous contents of +self+ is overwritten.

|*_void_* ~type~Dtor(*_Type_* * +self+)
|
Destroy list +self+.
Stored elements are destroyed as well by calling the respective destructors.

|*_int_* ~type~Equal(*_Type_* * +lt+, *_Type_* * +rt+)
|
Return non-zero value if lists +lt+ and +rt+ are considered equal by contents and zero value otherwise.

|*_size_t_* ~type~Identify(*_Type_* * +self+)
|
Return hash code for list +self+.
|===

=== Basic operations

[cols=2*]
|===
|*_int_* ~type~Contains(*_Type_* * +self+, *_E_* +what+)
|
Return non-zero value if list +self+ contains (at least) one element considered equal to +what+ and zero value otherwise.

|*_int_* ~type~Empty(*_Type_* * +self+)
|
Return non-zero value if list +self+ contains no elements and zero value otherwise.

|*_E_* ~type~Find(*_Type_* * +self+, *_E_* +what+)
|
Return the _first_ element of stored in +self+ which is considered equal to +what+.

WARNING: +self+ *must* contain such element otherwise the behavior is undefined. See ~type~Contains().

|*_E_* ~type~Peek(*_Type_* * +self+)
|
Return a _copy_ of the head element of +self+.

WARNING: +self+ *must not* be empty otherwise the behavior is undefined. See ~type~Empty().

|*_E_* ~type~Pop(*_Type_* * +self+)
|
Remove head element of +self+ *and* return it.

NOTE: The function returns the element itself, *not* a copy.

WARNING: +self+ *must not* be empty otherwise the behavior is undefined. See ~type~Empty().

|*_void_* ~type~Purge(*_Type_* * +self+)
|
Remove and destroy all elements stored in +self+.

|*_void_* ~type~Push(*_Type_* * +self+, *_E_* +what+)
|
Place a _copy_ of the element +what+ to the head of +self+.

|*_int_* ~type~Replace(*_Type_* * +self+, *_E_* +with+)
|
Find the _first_ occurrence of +with+ in +self+ and replace it with a _copy_ of the element +with+.
Replaced element is destroyed.

Return non-zero value on successful replacement and zero value if no suitable element was found.

|*_int_* ~type~ReplaceAll(*_Type_* * +self+, *_E_* +with+)
|
Find _all_ occurrences of +with+ in +self+ and replace them with _copies_ of the element +with+.
All replaced elements are destroyed.

Return number of successful replacements.

|*_int_* ~type~ReplaceEx(*_Type_* * +self+, *_E_* +with+, *_int_* count)
|
Find at most +count+ occurrences of +with+ in +self+ and replace them with _copies_ of the element +with+.
If +count+ is negative, _all_ occurrences are replaced instead.
All replaced elements are destroyed.

Return number of successful replacements.

|*_int_* ~type~Remove(*_Type_* * +self+, *_E_* +what+)
|
Remove and destroy the _first_ occurrence of the element +what+ in +self+.

Return non-zero value if element was removed and zero value otherwise.

|*_int_* ~type~RemoveAll(*_Type_* * +self+, *_E_* +what+)
|
Remove and destroy _all_ occurrences of the element +what+ in +self+.

Return number of elements actually removed.

|*_int_* ~type~RemoveEx(*_Type_* * +self+, *_E_* +what+, *_int_* count)
|
Remove and destroy at most +count+ occurrences of the element +what+ in +self+.
If +count+ is negative, _all_ occurrences are removed instead.

Return number of elements actually removed.

|*_size_t_* ~type~Size(*_Type_* * +self+)
|
Return number of elements stored in +self+.
|===

=== Iteration

[cols=2*]
|===
|*_void_* ~it~Ctor(*_IteratorType_* * +it+, *_Type_* * +self+)
|
Create a new iterator +it+ on list +self+.

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
class List < Collection
  
  def initialize(*args)
    super
    @capability.subtract [:less]
  end
  
  def write_exported_types(stream)
    stream << %$
      /***
      **** #{type}<#{element.type}> (#{self.class})
      ***/
    $ if public?
    stream << %$
      typedef struct #{node} #{node};
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{node}* head_node;
        size_t node_count;
      };
      struct #{it} {
        int start;
        #{type}* list;
        #{node}* this_node;
      };
      struct #{node} {
        #{element.type} element;
        #{node}* next_node;
      };
    $
  end
  
  def write_exported_declarations(stream, declare, define)
    stream << %$
      #{declare} void #{ctor}(#{type}*);
      #{declare} void #{dtor}(#{type}*);
      #{declare} void #{copy}(#{type}*, #{type}*);
      #{declare} int #{equal}(#{type}*, #{type}*);
      #{declare} size_t #{identify}(#{type}*);
      #{declare} void #{purge}(#{type}*);
      #{declare} #{element.type} #{peek}(#{type}*);
      #{declare} #{element.type} #{pop}(#{type}*);
      #{declare} void #{push}(#{type}*, #{element.type});
      #{declare} int #{contains}(#{type}*, #{element.type});
      #{declare} #{element.type} #{find}(#{type}*, #{element.type});
      #define #{replace}(self, with) #{replaceEx}(self, with, 1)
      #define #{replaceAll}(self, with) #{replaceEx}(self, with, -1)
      #{declare} int #{replaceEx}(#{type}*, #{element.type}, int);
      #define #{remove}(self, what) #{removeEx}(self, what, 1)
      #define #{removeAll}(self, what) #{removeEx}(self, what, -1)
      #{declare} int #{removeEx}(#{type}*, #{element.type}, int);
      #{declare} size_t #{size}(#{type}*);
      #define #{empty}(self) (#{size}(self) == 0)
      #{declare} void #{itCtor}(#{it}*, #{type}*);
      #{declare} int #{itMove}(#{it}*);
      #{declare} #{element.type} #{itGet}(#{it}*);
    $
  end
  
  def write_implementations(stream, define)
    stream << %$
      #{define} #{element.type}* #{itGetRef}(#{it}*);
      #{define} void #{ctor}(#{type}* self) {
        #{assert}(self);
        self->head_node = NULL;
        self->node_count = 0;
      }
      #{define} void #{dtor}(#{type}* self) {
        #{node}* node;
        #{assert}(self);
        node = self->head_node;
        while(node) {
          #{node}* this_node = node;
          node = node->next_node;
          #{element.dtor("this_node->element")};
          #{free}(this_node);
        }
      }
      #{define} void #{copy}(#{type}* dst, #{type}* src) {
        #{it} it;
        #{assert}(src);
        #{assert}(dst);
        #{ctor}(dst);
        #{itCtor}(&it, src);
        while(#{itMove}(&it)) {
          #{push}(dst, *#{itGetRef}(&it));
        }
      }
      #{define} int #{equal}(#{type}* lt, #{type}* rt) {
        if(#{size}(lt) == #{size}(rt)) {
          #{it} lit, rit;
          #{itCtor}(&lit, lt);
          #{itCtor}(&rit, rt);
          while(#{itMove}(&lit) && #{itMove}(&rit)) {
            int equal;
            #{element.type} *le;
            #{element.type} *re;
            le = #{itGetRef}(&lit);
            re = #{itGetRef}(&rit);
            equal = #{element.equal("*le", "*re")};
            if(!equal) return 0;
          }
          return 1;
        } else
          return 0;
      }
      #{define} size_t #{identify}(#{type}* self) {
        #{node}* node;
        size_t result = 0;
        #{assert}(self);
        for(node = self->head_node; node != NULL; node = node->next_node) {
          result ^= #{element.identify("node->element")};
          result = AUTOC_RCYCLE(result);
        }
        return result;
      }
      #{define} void #{purge}(#{type}* self) {
        #{dtor}(self);
        #{ctor}(self);
      }
      #{define} #{element.type} #{peek}(#{type}* self) {
        #{element.type} result;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        #{element.copy("result", "self->head_node->element")};
        return result;
      }
      #{define} #{element.type} #{pop}(#{type}* self) {
        #{node}* node;
        #{element.type} result;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        node = self->head_node;
        result = node->element;
        self->head_node = self->head_node->next_node;
        --self->node_count;
        #{free}(node);
        return result;
      }
      #{define} void #{push}(#{type}* self, #{element.type} element) {
        #{node}* node;
        #{assert}(self);
        node = (#{node}*)#{malloc}(sizeof(#{node})); #{assert}(node);
        #{element.copy("node->element", "element")};
        node->next_node = self->head_node;
        self->head_node = node;
        ++self->node_count;
      }
      #{define} int #{contains}(#{type}* self, #{element.type} what) {
        #{node}* node;
        int found = 0;
        #{assert}(self);
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            found = 1;
            break;
          }
          node = node->next_node;
        }
        return found;
      }
      #{define} #{element.type} #{find}(#{type}* self, #{element.type} what) {
        #{node}* node;
        #{assert}(self);
        #{assert}(#{contains}(self, what));
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{element.type} result;
            #{element.copy("result", "node->element")};
            return result;
          }
          node = node->next_node;
        }
        #{abort}();
      }
      #{define} int #{replaceEx}(#{type}* self, #{element.type} with, int count) {
        #{node}* node;
        int replaced = 0;
        #{assert}(self);
        if(count == 0) return 0;
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "with")}) {
            #{element.dtor("node->element")};
            #{element.copy("node->element", "with")};
            ++replaced;
            if(count > 0 && replaced >= count) break;
          }
          node = node->next_node;
        }
        return replaced;
      }
      #{define} int #{removeEx}(#{type}* self, #{element.type} what, int count) {
        #{node} *node, *prev_node;
        int removed = 0;
        #{assert}(self);
        if(count == 0) return 0;
        node = self->head_node;
        prev_node = NULL;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{node}* this_node;
            if(prev_node) {
              this_node = prev_node->next_node = node->next_node;
            } else {
              this_node = self->head_node = node->next_node;
            }
            ++removed;
            --self->node_count;
            #{element.dtor("node->element")};
            #{free}(node);
            node = this_node;
            if(count > 0 && removed >= count) break;
          } else {
            prev_node = node;
            node = node->next_node;
          }
        }
        return removed;
      }
      #{define} size_t #{size}(#{type}* self) {
        #{assert}(self);
        return self->node_count;
      }
      #{define} void #{itCtor}(#{it}* self, #{type}* list) {
        #{assert}(self);
        #{assert}(list);
        self->start = 1;
        self->list = list;
      }
      #{define} int #{itMove}(#{it}* self) {
        #{assert}(self);
        if(self->start) {
          self->this_node = self->list->head_node;
          self->start = 0;
        } else {
          self->this_node = self->this_node ? self->this_node->next_node : NULL;
        }
        return self->this_node != NULL;
      }
      #{define} #{element.type} #{itGet}(#{it}* self) {
        #{element.type} result;
        #{assert}(self);
        #{assert}(self->this_node);
        #{element.copy("result", "self->this_node->element")};
        return result;
      }
      #{define} #{element.type}* #{itGetRef}(#{it}* self) {
        #{assert}(self);
        #{assert}(self->this_node);
        return &self->this_node->element;
      }
    $
  end
  
end # List


end # AutoC