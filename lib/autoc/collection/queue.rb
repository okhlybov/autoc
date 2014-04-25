require "autoc/collection"


module AutoC

  
class Queue < Collection
  
  def write_exported_types(stream)
    stream << %$
      typedef struct #{node} #{node};
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{node}* head_node;
        #{node}* tail_node;
        size_t node_count;
      };
      struct #{it} {
        #{node}* next_node;
        int forward;
      };
      struct #{node} {
        #{element.type} element;
        #{node}* prev_node;
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
      #{declare} void #{purge}(#{type}*);
      #{declare} #{element.type} #{head}(#{type}*);
      #{declare} #{element.type} #{tail}(#{type}*);
      #{declare} void #{append}(#{type}*, #{element.type});
      #{declare} void #{prepend}(#{type}*, #{element.type});
      #{declare} void #{chopHead}(#{type}*);
      #{declare} void #{chopTail}(#{type}*);
      #{declare} int #{contains}(#{type}*, #{element.type});
      #{declare} #{element.type} #{find}(#{type}*, #{element.type});
      #{declare} int #{replace}(#{type}*, #{element.type}, #{element.type});
      #{declare} int #{replaceAll}(#{type}*, #{element.type}, #{element.type});
      #{declare} int #{remove}(#{type}*, #{element.type});
      #{declare} int #{removeAll}(#{type}*, #{element.type});
      #{declare} size_t #{size}(#{type}*);
      #{declare} int #{empty}(#{type}*);
      #{declare} void #{itCtor}(#{it}*, #{type}*, int);
      #{declare} int #{itHasNext}(#{it}*);
      #{declare} #{element.type} #{itNext}(#{it}*);
    $
  end
  
  def write_implementations(stream, define)
    stream << %$
      #{define} void #{ctor}(#{type}* self) {
        #{assert}(self);
        self->head_node = self->tail_node = NULL;
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
        #{itCtor}(&it, src, 1);
        while(#{itHasNext}(&it)) {
          #{element.type} element;
          #{append}(dst, element = #{itNext}(&it));
          #{element.dtor("element")};
        }
      }
      #{define} int #{equal}(#{type}* lt, #{type}* rt) {
        if(#{size}(lt) == #{size}(rt)) {
          #{it} lit, rit;
          #{itCtor}(&lit, lt, 1);
          #{itCtor}(&rit, rt, 1);
          while(#{itHasNext}(&lit) && #{itHasNext}(&rit)) {
            int equal;
            #{element.type} le, re;
            le = #{itNext}(&lit);
            re = #{itNext}(&rit);
            equal = #{element.equal("le", "re")};
            #{element.dtor("le")};
            #{element.dtor("re")};
            if(!equal) return 0;
          }
          return 1;
        } else
          return 0;
      }
      #{define} void #{purge}(#{type}* self) {
        #{dtor}(self);
        #{ctor}(self);
      }
      #{define} #{element.type} #{head}(#{type}* self) {
        #{element.type} result;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        #{element.copy("result", "self->head_node->element")};
        return result;
      }
      #{define} #{element.type} #{tail}(#{type}* self) {
        #{element.type} result;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        #{element.copy("result", "self->tail_node->element")};
        return result;
      }
      #{define} void #{chopHead}(#{type}* self) {
        #{node}* node;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        node = self->head_node;
        #{element.dtor("node->element")};
        self->head_node = self->head_node->next_node;
        self->head_node->prev_node = NULL;
        --self->node_count;
        #{free}(node);
      }
      #{define} void #{chopTail}(#{type}* self) {
        #{node}* node;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        node = self->tail_node;
        #{element.dtor("node->element")};
        self->tail_node = self->tail_node->prev_node;
        self->tail_node->next_node = NULL;
        --self->node_count;
        #{free}(node);
      }
      #{define} void #{append}(#{type}* self, #{element.type} element) {
        #{node}* node;
        #{assert}(self);
        node = (#{node}*)#{malloc}(sizeof(#{node})); #{assert}(node);
        #{element.copy("node->element", "element")};
        if(#{empty}(self)) {
          node->prev_node = node->next_node = NULL;
          self->tail_node = self->head_node = node;
        } else {
          node->next_node = NULL;
          node->prev_node = self->tail_node;
          self->tail_node->next_node = node;
          self->tail_node = node;
        }
        ++self->node_count;
      }
      #{define} void #{prepend}(#{type}* self, #{element.type} element) {
        #{node}* node;
        #{assert}(self);
        node = (#{node}*)#{malloc}(sizeof(#{node})); #{assert}(node);
        #{element.copy("node->element", "element")};
        if(#{empty}(self)) {
          node->prev_node = node->next_node = NULL;
          self->tail_node = self->head_node = node;
        } else {
          node->prev_node = NULL;
          node->next_node = self->head_node;
          self->head_node->prev_node = node;
          self->head_node = node;
        }
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
        #{element.type} what;
        int found = 0;
        #{assert}(self);
        #{element.copy("what", "what_")};
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{node} *prev = node->prev_node, *next = node->next_node;
            #{element.dtor("node->element")};
            if(prev && next) {
              prev->next_node = next;
              next->prev_node = prev;
            } else if(prev) {
              prev->next_node = NULL;
              self->tail_node = prev;
            } else {
              next->prev_node = NULL;
              self->head_node = next;
            }
            --self->node_count;
            #{free}(node);
            found = 1;
            break;
          }
          node = node->next_node;
        }
        #{element.dtor("what")};
        return found;
      }
      #{define} int #{removeAll}(#{type}* self, #{element.type} what_) {
        #{node}* node;
        #{element.type} what;
        int count = 0;
        #{assert}(self);
        #{element.copy("what", "what_")};
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{node} *prev = node->prev_node, *next = node->next_node;
            #{element.dtor("node->element")};
            if(prev && next) {
              prev->next_node = next;
              next->prev_node = prev;
            } else if(prev) {
              prev->next_node = NULL;
              self->tail_node = prev;
            } else {
              next->prev_node = NULL;
              self->head_node = next;
            }
            --self->node_count;
            #{free}(node);
            ++count;
          }
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
      #{define} void #{itCtor}(#{it}* self, #{type}* list, int forward) {
        #{assert}(self);
        #{assert}(list);
        self->forward = forward;
        self->next_node = forward ? list->head_node : list->tail_node;
      }
      #{define} int #{itHasNext}(#{it}* self) {
        #{assert}(self);
        return self->next_node != NULL;
      }
      #{define} #{element.type} #{itNext}(#{it}* self) {
        #{node}* node;
        #{element.type} result;
        #{assert}(self);
        node = self->next_node;
        self->next_node = self->forward ? self->next_node->next_node : self->next_node->prev_node;
        #{element.copy("result", "node->element")};
        return result;
      }
    $
  end
  
end # Queue


end # AutoC