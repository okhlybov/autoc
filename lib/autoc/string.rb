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
    @ctor = define_redirector(:ctor, Function::Signature.new([type_ref^:self, "const #{char_type_ref}"^:pchar]))
    @capability.subtract [:constructible, :orderable] # No default constructor and no less operation defined
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
      #{declare} #{ctor.declaration};
      #{declare} #{dtor.declaration};
      #{declare} #{copy.declaration};
      #{declare} #{equal.declaration};
      #{declare} #{identify.declaration};
      #{declare} void #{render}(#{type_ref});
      #{define} void #{join}(#{type_ref} self) {
        #{assert}(self);
        if(self->list) #{render}(self);
      }
      #{define} size_t #{size}(#{type_ref} self) {
        #{assert}(self);
        #{join}(self);
        return self->size;
      }
      #{define} int #{within}(#{type_ref} self, size_t index) {
        #{assert}(self);
        /* Excessive call to #{join}(self); */
        return index < #{size}(self);
      }
      #{define} #{char_type} #{get}(#{type_ref} self, size_t index) {
        #{assert}(self);
        #{assert}(#{within}(self, index));
        #{join}(self);
        return self->string[index];
      }
      #{define} void #{set}(#{type_ref} self, size_t index, #{char_type} value) {
        #{assert}(self);
        #{assert}(#{within}(self, index));
        #{join}(self);
        self->string[index] = value;
      }
      #{define} const #{char_type_ref} #{chars}(#{type_ref} self) {
        #{assert}(self);
        #{join}(self);
        return self->string;
      }
      #{declare} void #{appendChars}(#{type_ref}, const #{char_type_ref});
      #{declare} void #{append}(#{type_ref}, #{type_ref});
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
        #{define} void #{render}(#{type_ref} self) {
          #{assert}(self);
          #{assert}(self->list);
          #{@list.it} it;
          #{char_type_ref} string;
          size_t index = 0, size = 0;
          #{@list.itCtor}(&it, self->strings);
          while(#{@list.itMove}(&it)) {
            size += strlen(#{@list.itGet}(&it));
          }
          string = (#{char_type_ref})#{malloc}((size + 1)*sizeof(#{char_type})); #{assert}(string);
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
        #{define} #{ctor.definition} {
          #{assert}(self);
          #{assert}(pchar);
          self->string = (#{char_type_ref})#{malloc}((self->size = strlen(pchar) + 1)*sizeof(#{char_type})); #{assert}(self->string);
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
          #{ctor}(dst, #{chars}(src));
        }
        #{define} #{equal.definition} {
          #{assert}(lt);
          #{assert}(rt);
          return strcmp(#{chars}(lt), #{chars}(rt)) == 0;
        }
        #{define} #{identify.definition} {
          size_t index, result = 0;
          #{assert}(self);
          #{join}(self);
          for(index = 0; index < self->size; ++index) {
            result ^= self->string[index];
            result = AUTOC_RCYCLE(result);
          }
          return result;
        }
        static void #{split}(#{type_ref} self) {
          #{@list.type} strings;
          #{assert}(self);
          if(!self->list) {
            strings = #{@list.new?}();
            #{@list.push}(self->strings, self->string);
            self->strings = strings;
            self->list = 1;
          }
        }
        #{define} void #{appendChars}(#{type_ref} self, const #{char_type_ref} pchar) {
          #{char_type_ref} string;
          #{assert}(self);
          #{assert}(pchar);
          #{split}(self);
          #{assert}(self->list);
          string = (#{char_type_ref})#{malloc}((strlen(pchar) + 1)*sizeof(#{char_type})); #{assert}(string);
          strcpy(string, pchar);
          #{@list.push}(self->strings, string);
        }
        #{define} void #{append}(#{type_ref} self, #{type_ref} from) {
          #{assert}(self);
          #{assert}(from);
          #{appendChars}(self, #{chars}(from));
        }
      $
    end
    
end # String


end # AutoC