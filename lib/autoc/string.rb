require "autoc/code"
require "autoc/type"


module AutoC
  

=begin

String is wrapper around the standard null-terminated C string which has the capabilities of both a plain string and a string builder optimized for appending and piecewise building.

Unlike the plain C string, this String type has value type semantics but it can be turned into the reference type with {AutoC::Reference}.

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
Create a new string +self+ with a _copy_ of the null-terminated C string +chars+.

NULL value of +chars+ is premitted; this case corresponds to an empty string "".
 
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
Return a _read-only view_ of the string in a form of the standard C null-terminated string.

The returned value need not to be freed.
  
WARNING: the returned value should be considered *volatile* and thus may be invalidated by a subsequent call to any String method!    
   
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

=== String buffer operations

Functions which provide the string buffer functionality.
This allows the incremental building of strings without excessive storage copying/reallocation.
  
[cols=2*]
|===
|*_int_* ~type~PushFormat(*_Type_* * +self+, *_const char*_* format, ...);
|
Append the _?sprintf()_- formatted string to +self+.

Return non-zero value of successful formatting and zero value if the call to _?sprintf()_ failed.
This usually happens due to the encoding error.

This function tries to use the _vsnprintf()_ standard C function if possible and falls back to *unsafe* _vsprintf()_ function which is ought to be present in every ANSI-compliant standard C library.
The former function is used on the platforms which are known to have it; the Autotools-compliant _HAVE_VSNPRINTF_ macro is also taken into consideration.
 _Note that the choice is obviously made at compile-time._

If using the _vsnprintf()_ and the allocated buffer is not large enough this function continuously expands the buffer to eventually accommodate the resulting string.
On the contrary, when the *unsafe* _vsprintf()_ is used, the buffer overrun causes this function to *abort()* in order to prevent possible data corruption.   

Current implementation operates on the heap-allocated buffer whose initial size is determined by the _AUTOC_BUFFER_SIZE_ macro.
If not explicitly set it defaults to 1024 bytes.
       
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
      #define #{join}(self) if(self->list) #{_join}(self);
      #define #{split}(self) if(!self->list) #{_split}(self);
      #{declare} void #{_join}(#{type_ref});
      #{declare} void #{_split}(#{type_ref});
      #{declare} #{ctor.declaration};
      #{declare} #{dtor.declaration};
      #{declare} #{copy.declaration};
      #{declare} #{equal.declaration};
      #{declare} #{identify.declaration};
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
      #{declare} int #{pushFormat}(#{type_ref}, const char*, ...);
      #{declare} void #{pushChars}(#{type_ref}, const #{char_type_ref});
      #{declare} void #{pushString}(#{type_ref}, #{type_ref});
      #define #{pushChar}(self, c) #{pushFormat}(self, "%c", (#{char_type})(c))
      #define #{pushInt}(self, i) #{pushFormat}(self, "%d", (int)(i))
      #define #{pushFloat}(self, f) #{pushFormat}(self, "%e", (double)(f))
      #define #{pushPtr}(self, p) #{pushFormat}(self, "%p", (void*)(p))
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
        #include <stdarg.h>
        #undef AUTOC_VSNPRINTF
        #if defined(_MSC_VER)
          #define AUTOC_VSNPRINTF _vsnprintf
        #elif defined(__DMC__)
          #define AUTOC_VSNPRINTF _vsnprintf
        #elif defined(HAVE_VSNPRINTF) || __STDC_VERSION__ >= 199901L /* Be Autotools-friendly, C99 must have snprintf()  */
          #define AUTOC_VSNPRINTF vsnprintf
        #endif
        #ifndef AUTOC_VSNPRINTF
          #warning Using unsafe vsprintf() function
        #endif
        #{define} void #{_join}(#{type_ref} self) {
          #{@list.it} it;
          #{char_type_ref} string;
          size_t* chunk; /* Avoiding excessive call to strlen() */
          size_t i, start = 0, total = 0;
          #{assert}(self);
          #{assert}(self->list);
          chunk = (size_t*)malloc(#{@list.size}(self->data.strings)*sizeof(size_t)); #{assert}(chunk);
          #{@list.itCtor}(&it, self->data.strings);
          for(i = 0; #{@list.itMove}(&it); ++i) {
            total += (chunk[i] = strlen(#{@list.itGet}(&it)));
          }
          string = (#{char_type_ref})#{malloc}((total + 1)*sizeof(#{char_type})); #{assert}(string);
          #{@list.itCtor}(&it, self->data.strings);
          /* List is a LIFO structure therefore merging should be performed from right to left */
          start = total - chunk[i = 0];
          while(#{@list.itMove}(&it)) {
            memcpy(&string[start], #{@list.itGet}(&it), chunk[i]*sizeof(#{char_type}));
            start -= chunk[++i];
          }
          string[total] = '\\0';
          
          #{free}(chunk);
          #{@list.free?}(self->data.strings);
          self->data.string = string;
          self->size = total;
          self->list = 0;
        }
        #{define} void #{_split}(#{type_ref} self) {
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
          if(chars) {
            self->data.string = (#{char_type_ref})#{malloc}((self->size = strlen(chars) + 1)*sizeof(#{char_type})); #{assert}(self->data.string);
            strcpy(self->data.string, chars); /* Using strcpy() here is considered to be safe because of the preceding call to strlen() */
            self->list = 0;
          } else {
            /* NULL argument is permitted and corresponds to empty string */
            self->data.strings = #{@list.new?}();
            self->list = 1;
          }
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
        #{define} int #{pushFormat}(#{type_ref} self, const char* format, ...) {
          va_list args;
          char* buffer;
          int i, c;
          int buffer_size =
            /* Avoid redefining the macro since this might affect the code appended after this one */
            #ifdef AUTOC_BUFFER_SIZE
              AUTOC_BUFFER_SIZE
            #else
              1024 /* Stay in sync with the documentation above! */
            #endif
          ;
          #{assert}(self);
          #{assert}(format);
          do {
            buffer = (char*)#{malloc}(buffer_size*sizeof(char)); #{assert}(buffer);
            va_start(args, format);
            #ifdef AUTOC_VSNPRINTF
              i = AUTOC_VSNPRINTF(buffer, buffer_size, format, args);
            #else
              i = vsprintf(buffer, format, args);
              if(i >= buffer_size) #{abort}();
              /* Since vsprintf() can not truncate its output this means the buffer overflow and
                 there is no guarantee that some useful data is not corrupted so its better
                 to crash right here than to let the corruption slip away uncaught */
            #endif
            c = (i > 0 && !(i < buffer_size));
            if(i > 0 && !c) #{pushChars}(self, buffer);
            va_end(args);
            #{free}(buffer);
            buffer_size *= 2;
          } while(c);
          return i >= 0;
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
        #{define} void #{pushString}(#{type_ref} self, #{type_ref} from) {
          #{assert}(self);
          #{assert}(from);
          #{pushChars}(self, #{chars}(from));
        }
        #undef AUTOC_SNPRINTF
      $
    end
    
end # String


end # AutoC