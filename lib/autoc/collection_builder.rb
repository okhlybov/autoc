require "autoc/code_builder"
require "autoc/type_builder"


module AutoC


class Collection < Type
  
  def self.coerce(type)
    type.is_a?(Type) ? type : UserDefinedType.new(type)
  end
  
  attr_reader :element
  
  def entities; super + [element] end
  
  def initialize(type_name, element_type, visibility = :public)
    super(type_name, visibility)
    @element = Collection.coerce(element_type)
  end
  
  def ctor(*args)
    if args.empty?
      super()
    else
      check_args(args, 1)
      obj = args.first
      super() + "(&#{obj})"
    end
  end
  
  def dtor(*args)
    if args.empty?
      super()
    else
      check_args(args, 1)
      obj = args.first
      super() + "(&#{obj})"
    end
  end
  
  def copy(*args)
    if args.empty?
      super()
    else
      check_args(args, 2)
      dst, src = args
      super() + "(&#{dst}, &#{src})"
    end
  end
  
  def equal(*args)
    args.empty? ? super() : raise("#{self.class} provides no equality testing functionality")
  end
  
  def less(*args)
    args.empty? ? super() : raise("#{self.class} provides no ordering functionality")
  end
  
  def identify(*args)
    args.empty? ? super() : raise("#{self.class} provides no hashing functionality")
  end
  
  private
  
  def check_args(args, nargs)
    raise "expected exactly #{nargs} argument(s)" unless args.size == nargs
  end
  
end # Collection


class Vector < Collection

  def ctor(*args)
    args.empty? ? super() : raise("#{self.class} provides no default constructor")
  end
  
  def equal(*args)
    if args.empty?
      super()
    else
      check_args(args, 2)
      lt, rt = args
      super() + "(&#{lt}, &#{rt})"
    end
  end
  
  def write_exported_types(stream)
    stream << %$
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{element.type}* values;
        size_t element_count;
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
      #{declare} void #{copy}(#{type}*, #{type}*);
      #{declare} void #{resize}(#{type}*, size_t);
      #{declare} void #{itCtor}(#{it}*, #{type}*);
      #{declare} int #{itHasNext}(#{it}*);
      #{declare} #{element.type} #{itNext}(#{it}*);
      #{define} size_t #{size}(#{type}* self) {
        #{assert}(self);
        return self->element_count;
      }
      #{define} int #{within}(#{type}* self, size_t index) {
        #{assert}(self);
        return index < #{size}(self);
      }
      #{define} #{element.type} #{get}(#{type}* self, size_t index) {
        #{element.type} result;
        #{assert}(self);
        #{assert}(#{within}(self, index));
        #{element.copy("result", "self->values[index]")};
        return result;
      }
      #{define} void #{set}(#{type}* self, size_t index, #{element.type} value) {
        #{assert}(self);
        #{assert}(#{within}(self, index));
        #{element.dtor("self->values[index]")};
        #{element.copy("self->values[index]", "value")};
      }
      #{declare} void #{sort}(#{type}*);
      #{declare} int #{equal}(#{type}*, #{type}*);
    $
  end
  
  def write_implementations(stream, define)
    stream << %$
      static void #{allocate}(#{type}* self, size_t element_count) {
        #{assert}(self);
        #{assert}(element_count > 0);
        self->element_count = element_count;
        self->values = (#{element.type}*)#{malloc}(element_count*sizeof(#{element.type})); #{assert}(self->values);
      }
      #{define} void #{ctor}(#{type}* self, size_t element_count) {
        size_t index;
        #{assert}(self);
        #{allocate}(self, element_count);
        for(index = 0; index < #{size}(self); ++index) {
          #{element.ctor("self->values[index]")};
        }
      }
      #{define} void #{dtor}(#{type}* self) {
        size_t index;
        #{assert}(self);
        for(index = 0; index < #{size}(self); ++index) {
          #{element.dtor("self->values[index]")};
        }
        #{free}(self->values);
      }
      #{define} void #{copy}(#{type}* dst, #{type}* src) {
        size_t index, size;
        #{assert}(src);
        #{assert}(dst);
        #{allocate}(dst, size = #{size}(src));
        for(index = 0; index < size; ++index) {
          #{element.copy("dst->values[index]", "src->values[index]")};
        }
      }
      #{define} void #{resize}(#{type}* self, size_t element_count) {
        size_t index;
        #{assert}(self);
        if(#{size}(self) != element_count) {
          size_t count;
          #{element.type}* values = (#{element.type}*)#{malloc}(element_count*sizeof(#{element.type})); #{assert}(values);
          if(#{size}(self) > element_count) {
            for(index = element_count; index < #{size}(self); ++index) {
              #{element.dtor("self->values[index]")};
            }
            count = element_count;
          } else {
            for(index = element_count; index < #{size}(self); ++index) {
              #{element.ctor("self->values[index]")};
            }
            count = #{size}(self);
          }
          for(index = 0; index < count; ++index) {
            values[index] = self->values[index];
          }
          #{free}(self->values);
          self->element_count = element_count;
          self->values = values;
        }
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
      static int #{comparator}(void* lp_, void* rp_) {
        #{element.type}* lp = (#{element.type}*)lp_;
        #{element.type}* rp = (#{element.type}*)rp_;
        if(#{element.equal("*lp", "*rp")}) {
          return 0;
        } else if(#{element.less("*lp", "*rp")}) {
          return -1;
        } else {
          return +1;
        }
      }
      #{define} void #{sort}(#{type}* self) {
        typedef int (*F)(const void*, const void*);
        #{assert}(self);
        qsort(self->values, #{size}(self), sizeof(#{element.type}), (F)#{comparator});
      }
      #{define} int #{equal}(#{type}* lt, #{type}* rt) {
        size_t index, size;
        #{assert}(lt);
        #{assert}(rt);
        if(#{size}(lt) == (size = #{size}(rt))) {
          for(index = 0; index < size; ++index) {
            if(!#{element.equal("lt->values[index]", "rt->values[index]")}) return 0;
          }
          return 1;
        } else {
          return 0;
        }
      }
    $
  end
  
end # Vector


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


class HashSet < Collection

  def initialize(*args)
    super
    @list = List.new(list, element, :static)
  end
  
  def write_exported_types(stream)
    @list.write_exported_types(stream)
    stream << %$
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{@list.type}* buckets;
        size_t bucket_count, min_bucket_count;
        size_t size, min_size, max_size;
        unsigned min_fill, max_fill, capacity_multiplier; /* ?*1e-2 */
      };
      struct #{it} {
        #{type}* set;
        int bucket_index;
        #{@list.it} it;
      };
    $
  end
  
  def write_exported_declarations(stream, declare, define)
    stream << %$
      #{declare} void #{ctor}(#{type}*);
      #{declare} void #{dtor}(#{type}*);
      #{declare} void #{purge}(#{type}*);
      #{declare} void #{rehash}(#{type}*);
      #{declare} int #{contains}(#{type}*, #{element.type});
      #{declare} #{element.type} #{get}(#{type}*, #{element.type});
      #{declare} size_t #{size}(#{type}*);
      #{declare} int #{empty}(#{type}*);
      #{declare} int #{put}(#{type}*, #{element.type});
      #{declare} void #{replace}(#{type}*, #{element.type});
      #{declare} int #{remove}(#{type}*, #{element.type});
      #{declare} void #{not!}(#{type}*, #{type}*);
      #{declare} void #{and!}(#{type}*, #{type}*);
      #{declare} void #{or!}(#{type}*, #{type}*);
      #{declare} void #{xor!}(#{type}*, #{type}*);
      #{declare} void #{itCtor}(#{it}*, #{type}*);
      #{declare} int #{itHasNext}(#{it}*);
      #{declare} #{element.type} #{itNext}(#{it}*);
    $
  end

  def write_implementations(stream, define)
    @list.write_exported_declarations(stream, static, inline)
    @list.write_implementations(stream, static)
    stream << %$
      #{define} void #{ctor}(#{type}* self) {
        #{assert}(self);
        self->min_bucket_count = 16;
        self->min_fill = 20;
        self->max_fill = 80;
        self->min_size = (size_t)((float)self->min_fill/100*self->min_bucket_count);
        self->max_size = (size_t)((float)self->max_fill/100*self->min_bucket_count);
        self->capacity_multiplier = 200;
        self->buckets = NULL;
        #{rehash}(self);
      }
      #{define} void #{dtor}(#{type}* self) {
        size_t i;
        #{assert}(self);
        for(i = 0; i < self->bucket_count; ++i) {
          #{@list.dtor}(&self->buckets[i]);
        }
        #{free}(self->buckets);
      }
      #{define} void #{purge}(#{type}* self) {
        #{assert}(self);
        #{dtor}(self);
        self->buckets = NULL;
        #{rehash}(self);
      }
      #{define} void #{rehash}(#{type}* self) {
        #{@list.type}* buckets;
        size_t i, bucket_count, size, fill;
        #{assert}(self);
        #{assert}(self->min_fill > 0);
        #{assert}(self->max_fill > 0);
        #{assert}(self->min_fill < self->max_fill);
        #{assert}(self->min_bucket_count > 0);
        if(self->buckets) {
          if(self->min_size < self->size && self->size < self->max_size) return;
          fill = (size_t)((float)self->size/self->bucket_count*100);
          if(fill > self->max_fill) {
            bucket_count = (size_t)((float)self->bucket_count/100*self->capacity_multiplier);
          } else
          if(fill < self->min_fill && self->bucket_count > self->min_bucket_count) {
            bucket_count = (size_t)((float)self->bucket_count/self->capacity_multiplier*100);
            if(bucket_count < self->min_bucket_count) bucket_count = self->min_bucket_count;
          } else
            return;
          size = self->size;
          self->min_size = (size_t)((float)self->min_fill/100*size);
          self->max_size = (size_t)((float)self->max_fill/100*size);
        } else {
          bucket_count = self->min_bucket_count;
          size = 0;
        }
        buckets = (#{@list.type}*)#{malloc}(bucket_count*sizeof(#{@list.type})); #{assert}(buckets);
        for(i = 0; i < bucket_count; ++i) {
          #{@list.ctor}(&buckets[i]);
        }
        if(self->buckets) {
          #{it} it;
          #{itCtor}(&it, self);
          while(#{itHasNext}(&it)) {
            #{@list.type}* bucket;
            #{element.type} element = #{itNext}(&it);
            bucket = &buckets[#{element.identify("element")} % bucket_count];
            #{@list.add}(bucket, element);
          }
          #{dtor}(self);
        }
        self->buckets = buckets;
        self->bucket_count = bucket_count;
        self->size = size;
      }
      #{define} int #{contains}(#{type}* self, #{element.type} _element_) {
        int result;
        #{element.type} element;
        #{assert}(self);
        #{element.copy("element", "_element_")};
        result = #{@list.contains}(&self->buckets[#{element.identify("element")} % self->bucket_count], element);
        #{element.dtor("element")};
        return result;
      }
      #{define} #{element.type} #{get}(#{type}* self, #{element.type} _element_) {
        #{element.type} result;
        #{element.type} element;
        #{assert}(self);
        #{element.copy("element", "_element_")};
        #{assert}(#{contains}(self, element));
        result = #{@list.find}(&self->buckets[#{element.identify("element")} % self->bucket_count], element);
        #{element.dtor("element")};
        return result;
      }
      #{define} size_t #{size}(#{type}* self) {
        #{assert}(self);
        return self->size;
      }
      #{define} int #{empty}(#{type}* self) {
        #{assert}(self);
        return !self->size;
      }
      #{define} int #{put}(#{type}* self, #{element.type} _element_) {
        #{element.type} element;
        #{@list.type}* bucket;
        int contained = 1;
        #{assert}(self);
        #{element.copy("element", "_element_")};
        bucket = &self->buckets[#{element.identify("element")} % self->bucket_count];
        if(!#{@list.contains}(bucket, element)) {
          #{@list.add}(bucket, element);
          ++self->size;
          contained = 0;
          #{rehash}(self);
        }
        #{element.dtor("element")};
        return contained;
      }
      #{define} void #{replace}(#{type}* self, #{element.type} _element_) {
        #{element.type} element;
        #{@list.type}* bucket;
        #{assert}(self);
        #{element.copy("element", "_element_")};
        bucket = &self->buckets[#{element.identify("element")} % self->bucket_count];
        if(!#{@list.replace}(bucket, element, element)) {
          #{@list.add}(bucket, element);
          ++self->size;
          #{rehash}(self);
        }
        #{element.dtor("element")};
      }
      #{define} int #{remove}(#{type}* self, #{element.type} _what_) {
        #{element.type} what;
        #{@list.type}* bucket;
        int removed = 0;
        #{assert}(self);
        #{element.copy("what", "_what_")};
        bucket = &self->buckets[#{element.identify("what")} % self->bucket_count];
        if(#{@list.remove}(bucket, what)) {
          --self->size;
          removed = 1;
          #{rehash}(self);
        }
        #{element.dtor("what")};
        return removed;
      }
      #{define} void #{not!}(#{type}* self, #{type}* other) {
        #{it} it;
        #{assert}(self);
        #{assert}(other);
        #{itCtor}(&it, other);
        while(#{itHasNext}(&it)) {
          #{remove}(self, #{itNext}(&it));
        }
        #{rehash}(self);
      }
      #{define} void #{or!}(#{type}* self, #{type}* other) {
        #{it} it;
        #{assert}(self);
        #{assert}(other);
        #{itCtor}(&it, other);
        while(#{itHasNext}(&it)) {
          #{put}(self, #{itNext}(&it));
        }
        #{rehash}(self);
      }
      #{define} void #{and!}(#{type}* self, #{type}* other) {
        #{it} it;
        #{type} set;
        #{assert}(self);
        #{assert}(other);
        #{ctor}(&set);
        #{itCtor}(&it, self);
        while(#{itHasNext}(&it)) {
          #{element.type} element = #{itNext}(&it);
          if(#{contains}(other, element)) #{put}(&set, element);
        }
        #{itCtor}(&it, other);
        while(#{itHasNext}(&it)) {
          #{element.type} element = #{itNext}(&it);
          if(#{contains}(self, element)) #{put}(&set, element);
        }
        #{dtor}(self);
        self->buckets = set.buckets;
        self->size = set.size;
        #{rehash}(self);
        /*#{dtor}(&set);*/
      }
      #{define} void #{xor!}(#{type}* self, #{type}* other) {
        #{it} it;
        #{type} set;
        #{assert}(self);
        #{assert}(other);
        #{ctor}(&set);
        #{itCtor}(&it, self);
        while(#{itHasNext}(&it)) {
          #{element.type} element = #{itNext}(&it);
          if(!#{contains}(other, element)) #{put}(&set, element);
        }
        #{itCtor}(&it, other);
        while(#{itHasNext}(&it)) {
          #{element.type} element = #{itNext}(&it);
          if(!#{contains}(self, element)) #{put}(&set, element);
        }
        #{dtor}(self);
        self->buckets = set.buckets;
        self->size = set.size;
        #{rehash}(self);
        /*#{dtor}(&set);*/
      }
      #{define} void #{itCtor}(#{it}* self, #{type}* set) {
        #{assert}(self);
        self->set = set;
        self->bucket_index = 0;
        #{@list.itCtor}(&self->it, &set->buckets[0]);
      }
      #{define} int #{itHasNext}(#{it}* self) {
        #{assert}(self);
        if(#{@list.itHasNext}(&self->it)) {
          return 1;
        } else {
          size_t i; for(i = self->bucket_index+1; i < self->set->bucket_count; ++i) {
            if(!#{@list.empty}(&self->set->buckets[i])) {
              return 1;
            }
          }
          return 0;
        }
      }
      #{define} #{element.type} #{itNext}(#{it}* self) {
        #{assert}(self);
        #{assert}(#{itHasNext}(self));
          if(#{@list.itHasNext}(&self->it)) {
            return #{@list.itNext}(&self->it);
          } else {
            size_t i; for(i = self->bucket_index+1; i < self->set->bucket_count; ++i) {
            if(!#{@list.empty}(&self->set->buckets[i])) {
            #{@list.itCtor}(&self->it, &self->set->buckets[i]);
              self->bucket_index = i;
              return #{@list.itNext}(&self->it);
            }
          }
          #{abort}();
        }
      }
    $
  end
  
end # HashSet


class HashMap < Collection
  
  attr_reader :key

  alias :value :element
  
  def entities; super + [key] end
  
  def initialize(type, key_type, value_type, visibility = :public)
    super(type, value_type, visibility)
    @key = Collection.coerce(key_type)
    @entry = UserDefinedType.new(type: entry, identify: entryHash, equal: entryEqual, copy: entryCopy, dtor: entryDtor)
    @entry_set = HashSet.new(set, @entry)
  end
  
  def write_exported_types(stream)
    stream << %$
      typedef struct #{@entry.type} #{@entry.type};
      struct #{@entry.type} {
        #{key.type} key;
        #{value.type} value;
        int valid_value;
      };
    $
    @entry_set.write_exported_types(stream)
    stream << %$
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{@entry_set.type} entries;
      };
      struct #{it} {
        #{@entry_set.it} it;
      };
    $
  end

  def write_exported_declarations(stream, declare, define)
    stream << %$
      #{declare} void #{ctor}(#{type}*);
      #{declare} void #{dtor}(#{type}*);
      #{declare} void #{purge}(#{type}*);
      #{declare} void #{rehash}(#{type}*);
      #{declare} size_t #{size}(#{type}*);
      #{declare} int #{empty}(#{type}*);
      #{declare} int #{containsKey}(#{type}*, #{key.type});
      #{declare} #{value.type} #{get}(#{type}*, #{key.type});
      #{declare} int #{put}(#{type}*, #{key.type}, #{value.type});
      #{declare} void #{replace}(#{type}*, #{key.type}, #{value.type});
      #{declare} int #{remove}(#{type}*, #{key.type});
      #{declare} void #{itCtor}(#{it}*, #{type}*);
      #{declare} int #{itHasNext}(#{it}*);
      #{declare} #{key.type} #{itNextKey}(#{it}*);
      #{declare} #{value.type} #{itNextValue}(#{it}*);
      #{declare} #{@entry.type} #{itNext}(#{it}*);
    $
  end

  def write_implementations(stream, define)
    stream << %$
      static #{@entry.type} #{entryKeyOnly}(#{key.type} key) {
        #{@entry.type} entry;
        entry.key = key;
        entry.valid_value = 0;
        return entry;
      }
      static #{@entry.type} #{entryKeyValue}(#{key.type} key, #{value.type} value) {
        #{@entry.type} entry;
        entry.key = key;
        entry.value = value;
        entry.valid_value = 1;
        return entry;
      }
      static size_t #{entryHash}(#{@entry.type} entry) {
        return #{key.identify("entry.key")};
      }
      static int #{entryEqual}(#{@entry.type} lt, #{@entry.type} rt) {
        return #{key.equal("lt.key", "rt.key")};
      }
      #define #{entryCopy}(dst, src) #{entryCopyP}(&dst, &src)
      static void #{entryCopyP}(#{@entry.type}* dst, #{@entry.type}* src) {
        #{key.copy("dst->key", "src->key")};
        if((dst->valid_value = src->valid_value)) #{value.copy("dst->value", "src->value")};
      }
      static void #{entryDtor}(#{@entry.type} entry) {
        #{key.dtor("entry.key")};
        if(entry.valid_value) #{value.dtor("entry.value")};
      }
    $
    @entry_set.write_exported_declarations(stream, static, inline)
    @entry_set.write_implementations(stream, static)
    stream << %$
      #{define} void #{ctor}(#{type}* self) {
        #{assert}(self);
        #{@entry_set.ctor}(&self->entries);
      }
      #{define} void #{dtor}(#{type}* self) {
        #{assert}(self);
        #{@entry_set.dtor}(&self->entries);
      }
      #{define} void #{rehash}(#{type}* self) {
        #{assert}(self);
        #{@entry_set.rehash}(&self->entries);
      }
      #{define} void #{purge}(#{type}* self) {
        #{assert}(self);
        #{@entry_set.purge}(&self->entries);
      }
      #{define} size_t #{size}(#{type}* self) {
        #{assert}(self);
        return #{@entry_set.size}(&self->entries);
      }
      #{define} int #{empty}(#{type}* self) {
        #{assert}(self);
        return #{@entry_set.empty}(&self->entries);
      }
      #{define} int #{containsKey}(#{type}* self, #{key.type} key) {
        int result;
        #{@entry.type} entry;
        #{assert}(self);
        entry = #{entryKeyOnly}(key);
        result = #{@entry_set.contains}(&self->entries, entry);
        #{@entry.dtor("entry")};
        return result;
      }
      #{define} #{value.type} #{get}(#{type}* self, #{key.type} key) {
        #{value.type} result;
        #{@entry.type} entry;
        #{assert}(self);
        entry = #{entryKeyOnly}(key);
        #{assert}(#{containsKey}(self, key));
        result = #{@entry_set.get}(&self->entries, entry).value;
        #{@entry.dtor("entry")};
        return result;
      }
      #{define} int #{put}(#{type}* self, #{key.type} key, #{value.type} value) {
        #{@entry.type} entry = #{entryKeyValue}(key, value);
        #{assert}(self);
        if(!#{containsKey}(self, key)) {
          #{@entry_set.put}(&self->entries, entry);
          #{@entry.dtor("entry")};
          return 1;
        } else {
          #{@entry.dtor("entry")};
          return 0;
        }
      }
      #{define} void #{replace}(#{type}* self, #{key.type} key, #{value.type} value) {
        #{@entry.type} entry;
        #{assert}(self);
        entry = #{entryKeyValue}(key, value);
        #{@entry_set.replace}(&self->entries, entry);
        #{@entry.dtor("entry")};
      }
      #{define} int #{remove}(#{type}* self, #{key.type} key) {
        int removed;
        #{@entry.type} entry;
        #{assert}(self);
        entry = #{entryKeyOnly}(key);
        removed = #{@entry_set.remove}(&self->entries, entry);
        #{@entry.dtor("entry")};
        return removed;
      }
      #{define} void #{itCtor}(#{it}* self, #{type}* map) {
        #{assert}(self);
        #{assert}(map);
        #{@entry_set.itCtor}(&self->it, &map->entries);
      }
      #{define} int #{itHasNext}(#{it}* self) {
        #{assert}(self);
        return #{@entry_set.itHasNext}(&self->it);
      }
      #{define} #{key.type} #{itNextKey}(#{it}* self) {
        #{assert}(self);
        return #{@entry_set.itNext}(&self->it).key;
      }
      #{define} #{value.type} #{itNextValue}(#{it}* self) {
        #{assert}(self);
        return #{@entry_set.itNext}(&self->it).value;
      }
      #{define} #{@entry.type} #{itNext}(#{it}* self) {
        #{assert}(self);
        return #{@entry_set.itNext}(&self->it);
      }
    $
  end
  
end # HashMap


end # AutoC