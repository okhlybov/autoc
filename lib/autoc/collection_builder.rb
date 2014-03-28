require "autoc/code_builder"
require "autoc/type_builder"


module AutoC


class Collection < Type
  
  attr_reader :element
  
  def initialize(type_name, element_type, visibility = :public)
    super(type: type_name, visibility: visibility)
    @element = Type.coerce(element_type)
  end
  
end # Collection


class Vector < Collection

  [:ctor, :dtor].each {|m| undef_method m}
  
  def write_exported_types(stream)
    stream << %$
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{element.type}* values;
        size_t element_count;
        size_t ref_count;
      };
      struct #{it} {
        #{type}* vector;
        size_t index;
      };
    $
  end
  
  def write_exported_declarations(stream, declare, define)
    stream << %$
      #{declare} void #{ctor}(#{type}*, size_t);
      #{declare} void #{dtor}(#{type}*);
      #{declare} #{type}* #{new}(size_t);
      #{declare} void #{destroy}(#{type}*);
      #{declare} void #{resize}(#{type}*, size_t);
      #{declare} int #{within}(#{type}*, size_t);
      #{declare} void #{itCtor}(#{it}*, #{type}*);
      #{declare} int #{itHasNext}(#{it}*);
      #{declare} #{element.type} #{itNext}(#{it}*);
      #{define} #{element.type}* #{ref}(#{type}* self, size_t index) {
        #{assert}(self);
        #{assert}(#{within}(self, index));
        return &self->values[index];
      }
      #{define} #{element.type} #{get}(#{type}* self, size_t index) {
        #{assert}(self);
        #{assert}(#{within}(self, index));
        return *#{ref}(self, index);
      }
      #{define} void #{set}(#{type}* self, size_t index, #{element.type} value) {
        #{element.type}* ref;
        #{assert}(self);
        #{assert}(#{within}(self, index));
        ref = #{ref}(self, index);
        #{element.dtor("*ref")};
        #{element.copy("*ref", "value")};
      }
      #{define} size_t #{size}(#{type}* self) {
        #{assert}(self);
        return self->element_count;
      }
      #{declare} void #{sort}(#{type}*);
    $
  end
  
  def write_implementations(stream, define)
    stream << %$
      #{define} void #{ctor}(#{type}* self, size_t element_count) {
        int i;
        #{assert}(self);
        #{assert}(element_count > 0);
        self->element_count = element_count;
        self->values = (#{element.type}*)#{malloc}(element_count*sizeof(#{element.type})); #{assert}(self->values);
        for(i = 0; i < self->element_count; ++i) {
          #{element.ctor("self->values[i]")};
        }
      }
      #{define} void #{dtor}(#{type}* self) {
        int i;
        #{assert}(self);
        for(i = 0; i < self->element_count; ++i) {
          #{element.dtor("self->values[i]")};
        }
        #{free}(self->values);
      }
      #{define} #{type}* #{new}(size_t element_count) {
        #{type}* self = (#{type}*)#{malloc}(sizeof(#{type})); #{assert}(self);
        #{ctor}(self, element_count);
        self->ref_count = 0;
        return self;
      }
      #{define} void #{destroy}(#{type}* self) {
        #{assert}(self);
        if(!--self->ref_count) {
          #{dtor}(self);
          #{free}(self);
        }
      }
      #{define} void #{resize}(#{type}* self, size_t element_count) {
        int i;
        #{assert}(self);
        if(self->element_count != element_count) {
          size_t count;
          #{element.type}* values = (#{element.type}*)#{malloc}(element_count*sizeof(#{element.type})); #{assert}(values);
          if(self->element_count > element_count) {
            for(i = element_count; i < self->element_count; ++i) {
              #{element.dtor("self->values[i]")};
            }
            count = element_count;
          } else {
            for(i = element_count; i < self->element_count; ++i) {
              #{element.ctor("self->values[i]")};
            }
            count = self->element_count;
          }
          {
            size_t index;
            for(index = 0; index < count; ++index) {
              values[index] = self->values[index];
            }
          }
          #{free}(self->values);
          self->element_count = element_count;
          self->values = values;
        }
      }
      #{define} int #{within}(#{type}* self, size_t index) {
        #{assert}(self);
        return index < self->element_count;
      }
      #{define} void #{itCtor}(#{it}* self, #{type}* vector) {
        #{assert}(self);
        #{assert}(vector);
        self->vector = vector;
        self->index = 0;
      }
      #{define} int #{itHasNext}(#{it}* self) {
        #{assert}(self);
        return self->index < #{size}(self->vector);
      }
      #{define} #{element.type} #{itNext}(#{it}* self) {
        #{assert}(self);
        return #{get}(self->vector, self->index++);
      }
      static int #{comparator}(void* _lp_, void* _rp_) {
        #{element.type}* lp = (#{element.type}*)_lp_;
        #{element.type}* rp = (#{element.type}*)_rp_;
        if(#{element.equal("lp", "rp")}) {
          return 0;
        } else if(#{element.less("lp", "rp")}) {
          return -1;
        } else {
          return +1;
        }
      }
      #{define} void #{sort}(#{type}* self) {
        typedef int (*F)(const void*, const void*);
        #{assert}(self);
        qsort(self->values, self->element_count, sizeof(#{element.type}), (F)#{comparator});
      }
    $
  end
  
end # Vector


class List < Collection
  
  [:ctor, :dtor].each {|m| undef_method m}

  def write_exported_types(stream)
    stream << %$
      typedef struct #{node} #{node};
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{node}* head_node;
        size_t node_count;
        size_t ref_count;
      };
      struct #{it} {
        #{node}* next_node;
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
      #{declare} void #{purge}(#{type}*);
      #{declare} #{type}* #{new}(void);
      #{declare} void #{destroy}(#{type}*);
      #{declare} #{element.type} #{get}(#{type}*);
      #{declare} void #{add}(#{type}*, #{element.type});
      #{declare} void #{chop}(#{type}*);
      #{declare} int #{contains}(#{type}*, #{element.type});
      #{declare} #{element.type} #{find}(#{type}*, #{element.type});
      #{declare} int #{replace}(#{type}*, #{element.type}, #{element.type});
      #{declare} int #{replaceAll}(#{type}*, #{element.type}, #{element.type});
      #{declare} int #{remove}(#{type}*, #{element.type});
      #{declare} int #{removeAll}(#{type}*, #{element.type});
      #{declare} size_t #{size}(#{type}*);
      #{declare} int #{empty}(#{type}*);
      #{declare} void #{itCtor}(#{it}*, #{type}*);
      #{declare} int #{itHasNext}(#{it}*);
      #{declare} #{element.type} #{itNext}(#{it}*);
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
        #{it} it;
        #{node}* node;
        #{assert}(self);
        #{itCtor}(&it, self);
        while(#{itHasNext}(&it)) {
          #{element.type} e = #{itNext}(&it);
          #{element.dtor("e")};
        }
        node = self->head_node;
        while(node) {
          #{node}* this_node = node;
          node = node->next_node;
          #{free}(this_node);
        }
      }
      #{define} #{type}* #{new}(void) {
        #{type}* self = (#{type}*)#{malloc}(sizeof(#{type})); #{assert}(self);
        #{ctor}(self);
        self->ref_count = 0;
        return self;
      }
      #{define} void #{destroy}(#{type}* self) {
        #{assert}(self);
        if(!--self->ref_count) {
          #{dtor}(self);
          #{free}(self);
        }
      }
      #{define} void #{purge}(#{type}* self) {
        #{dtor}(self);
        #{ctor}(self);
      }
      #{define} #{element.type} #{get}(#{type}* self) {
        #{assert}(self);
        #{assert}(!#{empty}(self));
        return self->head_node->element;
      }
      #{define} void #{chop}(#{type}* self) {
        #{node}* node;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        node = self->head_node;
        #{element.dtor("node->element")};
        self->head_node = self->head_node->next_node;
        --self->node_count;
        #{free}(node);
      }
      #{define} void #{add}(#{type}* self, #{element.type} element) {
        #{node}* node;
        #{assert}(self);
        node = (#{node}*)#{malloc}(sizeof(#{node})); #{assert}(node);
        #{element.copy("node->element", "element")};
        node->next_node = self->head_node;
        self->head_node = node;
        ++self->node_count;
      }
      #{define} int #{contains}(#{type}* self, #{element.type} _what_) {
        #{node}* node;
        #{element.type} what;
        #{assert}(self);
        #{element.copy("what", "_what_")};
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{element.dtor("what")};
            return 1;
          }
          node = node->next_node;
        }
        #{element.dtor("what")};
        return 0;
      }
      #{define} #{element.type} #{find}(#{type}* self, #{element.type} _what_) {
        #{node}* node;
        #{element.type} what;
        #{assert}(self);
        #{element.copy("what", "_what_")};
        #{assert}(#{contains}(self, what));
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{element.dtor("what")};
            return node->element;
          }
          node = node->next_node;
        }
        /*#{element.dtor("what")};*/
        #{abort}();
      }
      #{define} int #{replace}(#{type}* self, #{element.type} _what_, #{element.type} _with_) {
        #{node}* node;
        #{element.type} what;
        #{element.type} with;
        #{assert}(self);
        #{element.copy("what", "_what_")};
        #{element.copy("with", "_with_")};
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{element.dtor("node->element")};
            #{element.copy("node->element", "with")};
            #{element.dtor("what")};
            #{element.dtor("with")};
            return 1;
          }
          node = node->next_node;
        }
        #{element.dtor("what")};
        #{element.dtor("with")};
        return 0;
      }
      #{define} int #{replaceAll}(#{type}* self, #{element.type} _what_, #{element.type} _with_) {
        #{node}* node;
        #{element.type} what;
        #{element.type} with;
        int count = 0;
        #{assert}(self);
        #{element.copy("what", "_what_")};
        #{element.copy("with", "_with_")};
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
      #{define} int #{remove}(#{type}* self, #{element.type} _what_) {
        #{node}* node;
        #{node}* prev_node;
        #{element.type} what;
        int found = 0;
        #{assert}(self);
        #{element.copy("what", "_what_")};
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
      #{define} int #{removeAll}(#{type}* self, #{element.type} _what_) {
        #{node}* node;
        #{node}* prev_node;
        #{element.type} what;
        int count = 0;
        #{assert}(self);
        #{element.copy("what", "_what_")};
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
        self->next_node = list->head_node;
      }
      #{define} int #{itHasNext}(#{it}* self) {
        #{assert}(self);
        return self->next_node != NULL;
      }
      #{define} #{element.type} #{itNext}(#{it}* self) {
        #{node}* node;
        #{assert}(self);
        node = self->next_node;
        self->next_node = self->next_node->next_node;
        return node->element;
      }
    $
  end
  
end # List


class Queue < Collection
  
  [:ctor, :dtor].each {|m| undef_method m}
  
  def write_exported_types(stream)
    stream << %$
      typedef struct #{node} #{node};
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{node}* head_node;
        #{node}* tail_node;
        size_t node_count;
        size_t ref_count;
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
      #{declare} void #{purge}(#{type}*);
      #{declare} #{type}* #{new}(void);
      #{declare} void #{destroy}(#{type}*);
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
        #{it} it;
        #{node}* node;
        #{assert}(self);
        #{itCtor}(&it, self, 1);
        while(#{itHasNext}(&it)) {
          #{element.type} e = #{itNext}(&it);
          #{element.dtor("e")};
        }
        node = self->head_node;
        while(node) {
          #{node}* this_node = node;
          node = node->next_node;
          #{free}(this_node);
        }
      }
      #{define} #{type}* #{new}(void) {
        #{type}* self = (#{type}*)#{malloc}(sizeof(#{type})); #{assert}(self);
        #{ctor}(self);
        self->ref_count = 0;
        return self;
      }
      #{define} void #{destroy}(#{type}* self) {
        #{assert}(self);
        if(!--self->ref_count) {
          #{dtor}(self);
          #{free}(self);
        }
      }
      #{define} void #{purge}(#{type}* self) {
        #{dtor}(self);
        #{ctor}(self);
      }
      #{define} #{element.type} #{head}(#{type}* self) {
        #{assert}(self);
        #{assert}(!#{empty}(self));
        return self->head_node->element;
      }
      #{define} #{element.type} #{tail}(#{type}* self) {
        #{assert}(self);
        #{assert}(!#{empty}(self));
        return self->tail_node->element;
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
      #{define} int #{contains}(#{type}* self, #{element.type} _what_) {
        #{node}* node;
        #{element.type} what;
        #{assert}(self);
        #{element.copy("what", "_what_")};
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{element.dtor("what")};
            return 1;
          }
          node = node->next_node;
        }
        #{element.dtor("what")};
        return 0;
      }
      #{define} #{element.type} #{find}(#{type}* self, #{element.type} _what_) {
        #{node}* node;
        #{element.type} what;
        #{assert}(self);
        #{element.copy("what", "_what_")};
        #{assert}(#{contains}(self, what));
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{element.dtor("what")};
            return node->element;
          }
          node = node->next_node;
        }
        #{abort}();
      }
      #{define} int #{replace}(#{type}* self, #{element.type} _what_, #{element.type} _with_) {
        #{node}* node;
        #{element.type} what;
        #{element.type} with;
        #{assert}(self);
        #{element.copy("what", "_what_")};
        #{element.copy("with", "_with_")};
        node = self->head_node;
        while(node) {
          if(#{element.equal("node->element", "what")}) {
            #{element.dtor("node->element")};
            #{element.copy("node->element", "with")}
            #{element.dtor("what")};
            #{element.dtor("with")};
            return 1;
          }
          node = node->next_node;
        }
        #{element.dtor("what")};
        #{element.dtor("with")};
        return 0;
      }
      #{define} int #{replaceAll}(#{type}* self, #{element.type} _what_, #{element.type} _with_) {
        #{node}* node;
        #{element.type} what;
        #{element.type} with;
        int count = 0;
        #{assert}(self);
        #{element.copy("what", "_what_")};
        #{element.copy("with", "_with_")};
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
      #{define} int #{remove}(#{type}* self, #{element.type} _what_) {
        #{node}* node;
        #{element.type} what;
        int found = 0;
        #{assert}(self);
        #{element.copy("what", "_what_")};
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
      #{define} int #{removeAll}(#{type}* self, #{element.type} _what_) {
        #{node}* node;
        #{element.type} what;
        int count = 0;
        #{assert}(self);
        #{element.copy("what", "_what_")};
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
        #{assert}(self);
        node = self->next_node;
        self->next_node = self->forward ? self->next_node->next_node : self->next_node->prev_node;
        return node->element;
      }
    $
  end
  
end # Queue


end # AutoC