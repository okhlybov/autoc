require "autoc/code"
require "autoc/type"


module AutoC
  

=begin

String is wrapper around standard C string which has the capabilities of a plain string and a string builder optimized for appending.

The String's default character type, *_CharType_*, is *_char_* although this can be changed. 

String generally obeys the Vector interface with respect to working with its contents.

== Generated C interface

=== Collection management

[cols="2*"]
|===
|*_void_* ~type~Copy(*_Type_* * +dst+, *_Type_* * +src+)
|
Create a new string +dst+ filled with the contents of +src+.

NOTE: Previous contents of +dst+ is overwritten.

|*_void_* ~type~Ctor(*_Type_* * +self+, *_const CharType *_* +chars+)
|
Create a new string +self+ with a _copy_ of null-terminated C string +chars+.

NOTE: Previous contents of +self+ is overwritten.

|*_void_* ~type~Dtor(*_Type_* * +self+)
|
Destroy string +self+.

|*_int_* ~type~Equal(*_Type_* * +lt+, *_Type_* * +rt+)
|
Return non-zero value if strings +lt+ and +rt+ are considered equal by contents and zero value otherwise.

|*_size_t_* ~type~Identify(*_Type_* * +self+)
|
Return hash code for string +self+.
|===

=== Basic operations

[cols=2*]
|===
|*_const CharType *_* ~type~Chars(*_Type_* * +self+)
|
Return a _view_ of the string in a form of standard C null-terminated array.
  
WARNING: the returned C array should be considered *volatile* and thus may be invalidated by a subsequent call to any String method!    
   
|*_CharType_* ~type~Get(*_Type_* * +self+, *_size_t_* +index+)
|
Return a _copy_ of the character stored in +self+ at position +index+.

WARNING: +index+ *must* be a valid index otherwise the behavior is undefined. See ~type~Within().

|*_void_* ~type~Set(*_Type_* * +self+, *_size_t_* +index+, *_CharType_* +what+)
|

Store a _copy_ of the character +what+ in string +self+ at position +index+.

WARNING: +index+ *must* be a valid index otherwise the behavior is undefined. See ~type~Within().

|*_size_t_* ~type~Size(*_Type_* * +self+)
|
Return number of characters stored in string +self+.

Note that this does not include the null terminator.

|*_int_* ~type~Within(*_Type_* * +self+, *_size_t_* +index+)
|
Return non-zero value if +index+ is a valid character index and zero value otherwise.
Valid index belongs to the range 0 ... ~type~Size()-1.
|===
   
=end  
class String < Type

  include Redirecting
  
  def char_type; :char end
  
  def char_type_ref; "#{char_type}*" end

  def initialize(type_name = :String, visibility = :public)
    super
    @list = Reference.new(List.new(list, char_type_ref, :public))
    initialize_redirectors
    @ctor = define_redirector(:ctor, Function::Signature.new([type_ref^:self, "const #{char_type_ref}"^:chars]))
  end
  
  # No default constructor provided
  def constructible?; false end

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
        union data {
          #{char_type_ref} string;
          #{@list.type} strings;
        } data;
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
      #{declare} void #{joinEx}(#{type_ref});
      #{define} void #{join}(#{type_ref} self) {
        #{assert}(self);
        if(self->list) #{joinEx}(self);
      }
      #{define} size_t #{size}(#{type_ref} self) {
        #{assert}(self);
        #{join}(self);
        return self->size;
      }
      #{define} int #{within}(#{type_ref} self, size_t index) {
        #{assert}(self);
        /* Omitting excessive call to #{join}() */
        return index < #{size}(self);
      }
      #{define} #{char_type} #{get}(#{type_ref} self, size_t index) {
        #{assert}(self);
        #{assert}(#{within}(self, index));
        #{join}(self);
        return self->data.string[index];
      }
      #{define} void #{set}(#{type_ref} self, size_t index, #{char_type} value) {
        #{assert}(self);
        #{assert}(#{within}(self, index));
        #{join}(self);
        self->data.string[index] = value;
      }
      #{define} const #{char_type_ref} #{chars}(#{type_ref} self) {
        #{assert}(self);
        #{join}(self);
        return self->data.string;
      }
      #{declare} void #{splitEx}(#{type_ref});
      #{define} void #{split}(#{type_ref} self) {
        #{assert}(self);
        if(!self->list) #{splitEx}(self);
      }
      #{declare} void #{pushChars}(#{type_ref}, const #{char_type_ref});
      #{declare} void #{push}(#{type_ref}, #{type_ref});
      #{declare} void #{pushChar}(#{type_ref}, #{char_type});
      #{declare} void #{pushInt}(#{type_ref}, int);
      #{declare} void #{pushFloat}(#{type_ref}, double);
      #{declare} void #{pushPtr}(#{type_ref}, void*);
    $
  end

    def write_impls(stream, define)
      super
      [@list.target, @list].each {|obj|
        obj.write_intf_decls(stream, static, inline)
        obj.write_impls(stream, static)
      }
      stream << %$
        #include <stdio.h>
        #include <string.h>
        #{define} void #{joinEx}(#{type_ref} self) {
          #{@list.it} it;
          #{char_type_ref} string;
          size_t* sizes; /* Avoiding excessive call to strlen() */
          size_t i, index = 0, size = 0;
          #{assert}(self);
          #{assert}(self->list);
          sizes = (size_t*)malloc(#{@list.size}(self->data.strings)*sizeof(size_t)); #{assert}(sizes);
          #{@list.itCtor}(&it, self->data.strings);
          for(i = 0; #{@list.itMove}(&it); ++i) {
            size += (sizes[i] = strlen(#{@list.itGet}(&it)));
          }
          string = (#{char_type_ref})#{malloc}((size + 1)*sizeof(#{char_type})); #{assert}(string);
          #{@list.itCtor}(&it, self->data.strings);
          for(i = 0; #{@list.itMove}(&it); ++i) {
            strcpy(&string[index], #{@list.itGet}(&it));
            index += sizes[i];
          }
          #{@list.free?}(self->data.strings);
          self->data.string = string;
          self->size = size;
          self->list = 0;
          #{free}(sizes);
        }
        #{define} void #{splitEx}(#{type_ref} self) {
          #{@list.type} strings;
          #{assert}(self);
          #{assert}(!self->list);
          strings = #{@list.new?}();
          #{@list.push}(strings, self->data.string);
          self->data.strings = strings;
          self->list = 1;
        }
        #{define} #{ctor.definition} {
          #{assert}(self);
          #{assert}(chars);
          self->data.string = (#{char_type_ref})#{malloc}((self->size = strlen(chars) + 1)*sizeof(#{char_type})); #{assert}(self->data.string);
          strcpy(self->data.string, chars);
          self->list = 0;
        }
        #{define} #{dtor.definition} {
          #{assert}(self);
          if(self->list) {
            #{@list.it} it;
            #{@list.itCtor}(&it, self->data.strings);
            while(#{@list.itMove}(&it)) {
              #{free}(#{@list.itGet}(&it));
            }
            #{@list.free?}(self->data.strings);
          } else {
            #{free}(self->data.string);
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
            result ^= self->data.string[index];
            result = AUTOC_RCYCLE(result);
          }
          return result;
        }
        #{define} void #{pushChars}(#{type_ref} self, const #{char_type_ref} chars) {
          #{char_type_ref} string;
          #{assert}(self);
          #{assert}(chars);
          #{split}(self);
          string = (#{char_type_ref})#{malloc}((strlen(chars) + 1)*sizeof(#{char_type})); #{assert}(string);
          strcpy(string, chars);
          #{@list.push}(self->data.strings, string);
        }
        #{define} void #{push}(#{type_ref} self, #{type_ref} from) {
          #{assert}(self);
          #{assert}(from);
          #{pushChars}(self, #{chars}(from));
        }
        #define AUTOC_BUF_SIZE 128
        #{define} void #{pushChar}(#{type_ref} self, #{char_type} value) {
          #{char_type} buffer[AUTOC_BUF_SIZE];
          #{assert}(self);
          sprintf(buffer, "%c", (int)value);
          #{pushChars}(self, buffer);
        }
        #{define} void #{pushInt}(#{type_ref} self, int value) {
          #{char_type} buffer[AUTOC_BUF_SIZE];
          #{assert}(self);
          sprintf(buffer, "%d", value);
          #{pushChars}(self, buffer);
        }
        #{define} void #{pushFloat}(#{type_ref} self, double value) {
          #{char_type} buffer[AUTOC_BUF_SIZE];
          #{assert}(self);
          sprintf(buffer, "%e", value);
          #{pushChars}(self, buffer);
        }
        #{define} void #{pushPtr}(#{type_ref} self, void* ptr) {
          #{char_type} buffer[AUTOC_BUF_SIZE];
          #{assert}(self);
          sprintf(buffer, "%p", ptr);
          #{pushChars}(self, buffer);
        }
        #undef AUTOC_BUF_SIZE
      $
    end
    
end # String


end # AutoC