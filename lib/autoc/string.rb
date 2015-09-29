require "autoc/code"
require "autoc/type"


module AutoC
  
  
class String < Type

  include Redirecting
  
  def char_type; :char end
  
  def char_type_ref; "#{char_type}*" end

  def initialize(type_name = :String, visibility = :public)
    super
    @list = Reference.new(List.new(list, char_type_ref, :public))
    initialize_redirectors
  end
  
  def write_intf_types(stream)
    stream << %$
      /***
      **** #{type}<#{char_type}> (#{self.class})
      ***/
    $ if public?
    [@list.target, @list].each {|obj| obj.write_intf_types(stream)} # TODO : this should be handled by the entity dependencies system 
    stream << %$
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        size_t size;
        union {
          #{char_type_ref} string;
          #{@list.type} strings;
        };
        int list;
      };
    $
  end

  def write_intf_decls(stream, declare, define)
    super
    write_redirectors(stream, declare, define)
    stream << %$
      #define #{ctor}(self) #{ctorPChar}(self, "")
      #{declare} void #{ctorPChar}(#{type_ref}, const #{char_type_ref});
      #{declare} #{dtor.declaration};
      #{declare} #{copy.declaration};
      #{declare} #{equal.declaration};
      #{declare} #{identify.declaration};
      #{declare} void #{renderEx}(#{type_ref});
      #{define} void #{render}(#{type_ref} self) {
        #{assert}(self);
        if(self->list) #{renderEx}(self);
      }
      #{define} size_t #{size}(#{type_ref} self) {
        #{assert}(self);
        #{render}(self);
        return self->size;
      }
      #{define} int #{within}(#{type_ref} self, size_t index) {
        #{assert}(self);
        /* Excessive call to #{render}(self); */
        return index < #{size}(self);
      }
      #{define} #{char_type} #{get}(#{type_ref} self, size_t index) {
        #{assert}(self);
        #{assert}(#{within}(self, index));
        #{render}(self);
        return self->string[index];
      }
      #{define} void #{set}(#{type_ref} self, size_t index, #{char_type} value) {
        #{assert}(self);
        #{assert}(#{within}(self, index));
        #{render}(self);
        self->string[index] = value;
      }
      #{declare} void #{appendPChar}(#{type_ref}, const #{char_type_ref});
    $
  end

    def write_impls(stream, define)
      super
      [@list.target, @list].each {|obj|
        obj.write_intf_decls(stream, static, inline)
        obj.write_impls(stream, static)
      }
      stream << %$
        #include <string.h>
        #{define} void #{renderEx}(#{type_ref} self) {
          #{assert}(self);
          #{assert}(self->list);
          #{@list.it} it;
          #{char_type_ref} string;
          size_t index = 0, size = 0;
          #{@list.itCtor}(&it, self->strings);
          while(#{@list.itMove}(&it)) {
            size += strlen(#{@list.itGet}(&it));
          }
          string = (#{char_type_ref})#{malloc}((size + 1)*sizeof(#{char_type}));
          #{@list.itCtor}(&it, self->strings);
          while(#{@list.itMove}(&it)) {
            #{char_type_ref} s = #{@list.itGet}(&it);
            strcpy(&string[index], s);
            index += strlen(s);
          }
          #{@list.free?}(self->strings);
          self->list = 0;
          self->string = string;
          self->size = size;
        }
        static const #{char_type_ref} #{pChar}(#{type_ref} self) {
          #{assert}(self);
          #{render}(self);
          return self->string;
        }
        #{define} void #{ctorPChar}(#{type_ref} self, const #{char_type_ref} pchar) {
          #{assert}(self);
          #{assert}(pchar);
          self->size = strlen(pchar);
          self->string = (#{char_type_ref})#{malloc}(self->size + sizeof(#{char_type}));
          strcpy(self->string, pchar);
          self->list = 0;
        }
        #{define} #{dtor.definition} {
          #{assert}(self);
          if(self->list) {
            #{@list.it} it;
            #{@list.itCtor}(&it, self->strings);
            while(#{@list.itMove}(&it)) {
              #{free}(#{@list.itGet}(&it));
            }
            #{@list.free?}(self->strings);
          } else {
            #{free}(self->string);
          }
        }
        #{define} #{copy.definition} {
          #{assert}(src);
          #{assert}(dst);
          #{ctorPChar}(dst, #{pChar}(src));
        }
        #{define} #{equal.definition} {
          #{assert}(lt);
          #{assert}(rt);
          return strcmp(#{pChar}(lt), #{pChar}(rt)) == 0;
        }
        #{define} #{identify.definition} {
          size_t index, result = 0;
          #{assert}(self);
          #{render}(self);
          for(index = 0; index < self->size; ++index) {
            result ^= self->string[index];
            result = AUTOC_RCYCLE(result);
          }
          return result;
        }
        static void #{setupList}(#{type_ref} self) {
          #{@list.type} strings;
          #{assert}(self);
          if(!self->list) {
            strings = #{@list.new?}();
            #{@list.push}(self->strings, self->string);
            self->strings = strings;
            self->list = 1;
          }
        }
        #{define} void #{appendPChar}(#{type_ref} self, const #{char_type_ref} pchar) {
          #{assert}(self);
          #{assert}(pchar);
          #{setupList}(self);
          #{assert}(self->list);
          /* TODO */
        }
      $
    end
    
end # String


end # AutoC