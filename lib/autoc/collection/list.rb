require "autoc/collection"


module AutoC
  

=begin

== Generated C interface

=== Collection management

- *_void_* ~type~Copy(*_Type_* * +dst+, *_Type_* * +src+)

- *_void_* ~type~Ctor(*_Type_* * +self+)

- *_void_* ~type~Dtor(*_Type_* * +self+)

- *_int_* ~type~Equal(*_Type_* * +lt+, *_Type_* * +rt+)

- *_size_t_* ~type~Identify(*_Type_* * +self+)

=== Basic operations

- *_void_* ~type~Chop(*_Type_* * +self+)

- *_int_* ~type~Contains(*_Type_* * +self+, *_E_* +value+)

- *_int_* ~type~Empty(*_Type_* * +self+)

-  *_E_* ~type~Find(*_Type_* * +self+, *_E_* +value+)

- *_E_* ~type~Get(*_Type_* * +self+)

- *_void_* ~type~Purge(*_Type_* * +self+)

- *_void_* ~type~Put(*_Type_* * +self+, *_E_* +value+)

- *_int_* ~type~Replace(*_Type_* * +self+, *_E_* +what+, *_E_* +with+)

- *_int_* ~type~ReplaceAll(*_Type_* * +self+, *_E_* +what+, *_E_* +with+)

- *_int_* ~type~Remove(*_Type_* * +self+, *_E_* +value+)

- *_int_* ~type~RemoveAll(*_Type_* * +self+, *_E_* +value+)

- *_size_t_* ~type~Size(*_Type_* * +self+)

=== Iteration

- *_void_* ~it~Ctor(*_IteratorType_* * +it+, *_Type_* * +self+)

- *_int_* ~it~Move(*_IteratorType_* * +it+)

- *_E_* ~it~Get(*_IteratorType_* * +it+)

=end
class List < Collection
  
  def write_exported_types(stream)
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
      #{declare} #{element.type} #{get}(#{type}*);
      #{declare} void #{put}(#{type}*, #{element.type});
      #{declare} void #{self.chop}(#{type}*);
      #{declare} int #{contains}(#{type}*, #{element.type});
      #{declare} #{element.type} #{find}(#{type}*, #{element.type});
      #{declare} int #{replace}(#{type}*, #{element.type}, #{element.type});
      #{declare} int #{replaceAll}(#{type}*, #{element.type}, #{element.type});
      #{declare} int #{remove}(#{type}*, #{element.type});
      #{declare} int #{removeAll}(#{type}*, #{element.type});
      #{declare} size_t #{size}(#{type}*);
      #{declare} int #{empty}(#{type}*);
      #{declare} void #{itCtor}(#{it}*, #{type}*);
      #{declare} int #{itMove}(#{it}*);
      #{declare} #{element.type} #{itGet}(#{it}*);
    $
  end
  
  def write_implementations(stream, define)
    stream << %$
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
          #{element.type} element;
          #{put}(dst, element = #{itGet}(&it));
          #{element.dtor("element")};
        }
      }
      #{define} int #{equal}(#{type}* lt, #{type}* rt) {
        if(#{size}(lt) == #{size}(rt)) {
          #{it} lit, rit;
          #{itCtor}(&lit, lt);
          #{itCtor}(&rit, rt);
          while(#{itMove}(&lit) && #{itMove}(&rit)) {
            int equal;
            #{element.type} le, re;
            le = #{itGet}(&lit);
            re = #{itGet}(&rit);
            equal = #{element.equal("le", "re")};
            #{element.dtor("le")};
            #{element.dtor("re")};
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
      #{define} #{element.type} #{get}(#{type}* self) {
        #{element.type} result;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        #{element.copy("result", "self->head_node->element")};
        return result;
      }
      #{define} void #{self.chop}(#{type}* self) {
        #{node}* node;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        node = self->head_node;
        #{element.dtor("node->element")};
        self->head_node = self->head_node->next_node;
        --self->node_count;
        #{free}(node);
      }
      #{define} void #{put}(#{type}* self, #{element.type} element) {
        #{node}* node;
        #{assert}(self);
        node = (#{node}*)#{malloc}(sizeof(#{node})); #{assert}(node);
        #{element.copy("node->element", "element")};
        node->next_node = self->head_node;
        self->head_node = node;
        ++self->node_count;
      }
      #{define} int #{contains}(#{type}* self, #{element.type} what_) {
        #{node}* node;
        #{element.type} what;
        int found = 0;
        #{assert}(self);
        #{element.copy("what", "what_")};
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            found = 1;
            break;
          }
          node = node->next_node;
        }
        #{element.dtor("what")};
        return found;
      }
      #{define} #{element.type} #{find}(#{type}* self, #{element.type} what_) {
        #{node}* node;
        #{element.type} what;
        #{assert}(self);
        #{element.copy("what", "what_")};
        #{assert}(#{contains}(self, what));
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{element.type} result;
            #{element.dtor("what")};
            #{element.copy("result", "node->element")};
            return result;
          }
          node = node->next_node;
        }
        #{element.dtor("what")};
        #{abort}();
      }
      #{define} int #{replace}(#{type}* self, #{element.type} what_, #{element.type} with_) {
        #{node}* node;
        #{element.type} what;
        #{element.type} with;
        int found = 0;
        #{assert}(self);
        #{element.copy("what", "what_")};
        #{element.copy("with", "with_")};
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{element.dtor("node->element")};
            #{element.copy("node->element", "with")};
            found = 1;
            break;
          }
          node = node->next_node;
        }
        #{element.dtor("what")};
        #{element.dtor("with")};
        return found;
      }
      #{define} int #{replaceAll}(#{type}* self, #{element.type} what_, #{element.type} with_) {
        #{node}* node;
        #{element.type} what;
        #{element.type} with;
        int count = 0;
        #{assert}(self);
        #{element.copy("what", "what_")};
        #{element.copy("with", "with_")};
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{element.dtor("node->element")};
            #{element.copy("node->element", "with")};
            ++count;
          }
          node = node->next_node;
        }
        #{element.dtor("what")};
        #{element.dtor("with")};
        return count;
      }
      #{define} int #{remove}(#{type}* self, #{element.type} what_) {
        #{node}* node;
        #{node}* prev_node;
        #{element.type} what;
        int found = 0;
        #{assert}(self);
        #{element.copy("what", "what_")};
        node = self->head_node;
        prev_node = NULL;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{element.dtor("node->element")};
            if(prev_node) {
              prev_node->next_node = node->next_node ? node->next_node : NULL;
            } else {
              self->head_node = node->next_node ? node->next_node : NULL;
            }
            --self->node_count;
            #{free}(node);
            found = 1;
            break;
          }
          prev_node = node;
          node = node->next_node;
        }
        #{element.dtor("what")};
        return found;
      }
      #{define} int #{removeAll}(#{type}* self, #{element.type} what_) {
        #{node}* node;
        #{node}* prev_node;
        #{element.type} what;
        int count = 0;
        #{assert}(self);
        #{element.copy("what", "what_")};
        node = self->head_node;
        prev_node = NULL;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{element.dtor("node->element")};
            if(prev_node) {
              prev_node->next_node = node->next_node ? node->next_node : NULL;
            } else {
              self->head_node = node->next_node ? node->next_node : NULL;
            }
            --self->node_count;
            #{free}(node);
            ++count;
          }
          prev_node = node;
          node = node->next_node;
        }
        #{element.dtor("what")};
        return count;
      }
      #{define} size_t #{size}(#{type}* self) {
        #{assert}(self);
        return self->node_count;
      }
      #{define} int #{empty}(#{type}* self) {
        #{assert}(self);
        return !self->node_count;
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