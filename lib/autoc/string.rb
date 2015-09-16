require "autoc/code"
require "autoc/type"


module AutoC
  
  
class String < Type

  include Redirecting
  
  def char_type; :char end
  
  def char_type_ref; "#{char_type}*" end
    
  def initialize(type_name = :String, visibility = :public)
    super
    setup_specials
  end
  
  def write_intf_types(stream)
    stream << %$
      /***
      **** #{type}<#{char_type}> (#{self.class})
      ***/
    $ if public?
    stream << %$
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        size_t size;
        #{char_type_ref} string;
      };
    $
  end

  def write_intf_decls(stream, declare, define)
    super
    stream << %$
      #define #{ctor}(self) #{ctorPChar}(self, "")
      #{declare} void #{ctorPChar}(#{type_ref}, const #{char_type_ref});
      #{declare} #{dtor.declaration};
      #{declare} #{copy.declaration};
      #{declare} #{equal.declaration};
      #{declare} #{identify.declaration};
      #{define} size_t #{size}(#{type_ref} self) {
        #{assert}(self);
        return self->size;
      }
      #{define} int #{within}(#{type_ref} self, size_t index) {
        #{assert}(self);
        return index < #{size}(self);
      }
      #{define} #{char_type} #{get}(#{type_ref} self, size_t index) {
        #{assert}(self);
        #{assert}(#{within}(self, index));
        return self->string[index];
      }
      #{define} void #{set}(#{type_ref} self, size_t index, #{char_type} value) {
        #{assert}(self);
        #{assert}(#{within}(self, index));
        self->string[index] = value;
      }
    $
  end

    def write_impls(stream, define)
      super
      stream << %$
        #include <string.h>
        static const #{char_type_ref} #{pChar}(#{type_ref} self) {
          #{assert}(self);
          return self->string;
        }
        #{define} void #{ctorPChar}(#{type_ref} self, const #{char_type_ref} pchar) {
          #{assert}(self);
          #{assert}(pchar);
          self->size = strlen(pchar);
          self->string = (#{char_type_ref})#{malloc}(self->size + sizeof(#{char_type}));
          strcpy(self->string, pchar);
        }
        #{define} #{dtor.definition} {
          #{assert}(self);
          #{free}(self->string);
        }
        #{define} #{copy.definition} {
          #{assert}(src);
          #{assert}(dst);
          #{ctorPChar}(dst, #{pChar}(src));
        }
        #{define} #{equal.definition} {
          #{assert}(lt);
          #{assert}(rt);
          return strcmp(lt->string, rt->string) == 0;
        }
        #{define} #{identify.definition} {
          size_t index, result = 0;
          #{assert}(self);
          for(index = 0; index < self->size; ++index) {
            result ^= self->string[index];
            result = AUTOC_RCYCLE(result);
          }
          return result;
        }
      $
    end
    
end # String


end # AutoC