require "autoc/collection"
require "autoc/collection/hash_set"


module AutoC

  
=begin

== Generated C interface

=== Collection management

[cols=2*]
|===
|*_void_* ~type~Copy(*_Type_* * +dst+, *_Type_* * +src+)
|
Create a new map +dst+ filled with the contents of +src+.
A copy operation is performed on all keys and values in +src+.

NOTE: Previous contents of +dst+ is overwritten.

|*_void_* ~type~Ctor(*_Type_* * +self+)
|
Create a new empty map +self+.

NOTE: Previous contents of +self+ is overwritten.

|*_void_* ~type~Dtor(*_Type_* * +self+)
|
Destroy map +self+.
Contained keys and values are destroyed as well by calling the respective destructors.

|*_int_* ~type~Equal(*_Type_* * +lt+, *_Type_* * +rt+)
|
Return non-zero value if maps +lt+ and +rt+ are considered equal by contents and zero value otherwise.

|*_size_t_* ~type~Identify(*_Type_* * +self+)
|
Return hash code for map +self+.
|===

=== Basic operations

[cols=2*]
|===
|*_int_* ~type~ContainsKey(*_Type_* * +self+, *_K_* +key+)
|
Return non-zero value if map +self+ contains an entry with a key considered equal to the key +key+ and zero value otherwise.

|*_int_* ~type~Empty(*_Type_* * +self+)
|
Return non-zero value if map +self+ contains no entries and zero value otherwise.

|*_E_* ~type~Get(*_Type_* * +self+, *_K_* +key+)
|
Return a _copy_ of the element in +self+ bound to a key which is considered equal to the key +key+.

WARNING: +self+ *must* contain such key otherwise the behavior is undefined. See ~type~Contains().

|*_void_* ~type~Purge(*_Type_* * +self+)
|
Remove and destroy all keys and values in +self+.

|*_void_* ~type~Put(*_Type_* * +self+, *_K_* +key+, *_E_* +value+)
|
Put a _copy_ of the element +value+ bound to a _copy_ of the key +key+ into +self+ *only if* there is no such key in +self+ which is considered equal to +key+.

Return non-zero value on successful put and zero value otherwise.

|*_int_* ~type~Replace(*_Type_* * +self+, *_K_* +key+, *_E_* +value+)
|
If map +self+ contains an element which is considered equal to the element +what+, replace that element with a _copy_ of the element +with+,
otherwise simply put a _copy_ of +with+ into +self+. Replaced element is destroyed.

Return non-zero value if the replacement was performed and zero value otherwise.

|*_int_* ~type~Remove(*_Type_* * +self+, *_K_* +key+)
|
Remove and destroy a key which is considered equal to the key +key+.
Destroy an element bound to that key.

Return non-zero value if a key/element pair was removed and zero value otherwise.

|*_size_t_* ~type~Size(*_Type_* * +self+)
|
Return number of key/element pairs contained in +self+.
|===

=== Iteration

[cols=2*]
|===
|*_void_* ~it~Ctor(*_IteratorType_* * +it+, *_Type_* * +self+)
|
Create a new iterator +it+ on map +self+.

NOTE: As the map is an unordered sequence, the traversal order is unspecified.

NOTE: Previous contents of +it+ is overwritten.

|*_int_* ~it~Move(*_IteratorType_* * +it+)
|
Advance iterator position of +it+ *and* return non-zero value if a new position is valid and zero value otherwise.

|*_K_* ~it~GetKey(*_IteratorType_* * +it+)
|
Return a _copy_ of the key from a key/value pair pointed to by the iterator +it+.

WARNING: current position *must* be valid otherwise the behavior is undefined. See ~it~Move().

|*_E_* ~it~GetValue(*_IteratorType_* * +it+)
|
Return a _copy_ of the element from a key/element pair to by the iterator +it+.

WARNING: current position *must* be valid otherwise the behavior is undefined. See ~it~Move().

|*_E_* ~it~Get(*_IteratorType_* * +it+)
|
Alias for ~it~GetValue().
|===

=end
class HashMap < Collection
  
  attr_reader :key

  alias :value :element
  
  def entities; super + [key] end
  
  def initialize(type, key_type, value_type, visibility = :public)
    super(type, value_type, visibility)
    @key = Collection.coerce(key_type)
    @entry = UserDefinedType.new(:type => entry, :identify => entryIdentify, :equal => entryEqual, :copy => entryCopy, :dtor => entryDtor)
    @set = HashSet.new(set, @entry, :static)
  end
  
  def write_exported_types(stream)
    stream << %$
      /***
      **** #{type}<#{key.type},#{value.type}> (#{self.class})
      ***/
    $ if public?
    stream << %$
      typedef struct #{@entry.type} #{@entry.type};
      struct #{@entry.type} {
        #{key.type} key;
        #{value.type} value;
        unsigned flags;
      };
    $
    @set.write_exported_types(stream)
    stream << %$
      typedef struct #{type} #{type};
      typedef struct #{it} #{it};
      struct #{type} {
        #{@set.type} entries;
      };
      struct #{it} {
        #{@set.it} it;
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
      #{declare} size_t #{size}(#{type}*);
      #{declare} int #{empty}(#{type}*);
      #{declare} int #{containsKey}(#{type}*, #{key.type});
      #{declare} #{value.type} #{get}(#{type}*, #{key.type});
      #{declare} int #{put}(#{type}*, #{key.type}, #{value.type});
      #{declare} void #{replace}(#{type}*, #{key.type}, #{value.type});
      #{declare} int #{remove}(#{type}*, #{key.type});
      #{declare} void #{itCtor}(#{it}*, #{type}*);
      #{declare} int #{itMove}(#{it}*);
      #{declare} #{key.type} #{itGetKey}(#{it}*);
      #{declare} #{value.type} #{itGetValue}(#{it}*);
      #define #{itGet}(x) #{itGetValue}(x)
    $
  end

  def write_implementations(stream, define)
    stream << %$
      #define AUTOC_VALID_VALUE 1
      #define AUTOC_VALID_KEY 2
      #define AUTOC_OWNED_VALUE 4
      #define AUTOC_OWNED_KEY 8
      static #{@entry.type} #{entryKeyOnlyRef}(#{key.type}* key) {
        #{@entry.type} entry;
        entry.key = *key;
        entry.flags = AUTOC_VALID_KEY;
        return entry;
      }
      static #{@entry.type} #{entryKeyValueRef}(#{key.type}* key, #{value.type}* value) {
        #{@entry.type} entry;
        entry.key = *key;
        entry.value = *value;
        entry.flags = (AUTOC_VALID_KEY | AUTOC_VALID_VALUE);
        return entry;
      }
      #define #{entryIdentify}(obj) #{entryIdentifyRef}(&obj)
      static size_t #{entryIdentifyRef}(#{@entry.type}* entry) {
        return #{key.identify("entry->key")};
      }
      #define #{entryEqual}(lt, rt) #{entryEqualRef}(&lt, &rt)
      static int #{entryEqualRef}(#{@entry.type}* lt, #{@entry.type}* rt) {
        return #{key.equal("lt->key", "rt->key")};
      }
      #define #{entryCopy}(dst, src) #{entryCopyRef}(&dst, &src)
      static void #{entryCopyRef}(#{@entry.type}* dst, #{@entry.type}* src) {
        #{assert}(src->flags & AUTOC_VALID_KEY);
        dst->flags = (AUTOC_VALID_KEY | AUTOC_OWNED_KEY);
        #{key.copy("dst->key", "src->key")};
        if(src->flags & AUTOC_VALID_VALUE) {
          dst->flags |= (AUTOC_VALID_VALUE | AUTOC_OWNED_VALUE);
          #{value.copy("dst->value", "src->value")};
        }
      }
      #define #{entryDtor}(obj) #{entryDtorRef}(&obj)
      static void #{entryDtorRef}(#{@entry.type}* entry) {
        #{assert}(entry->flags & AUTOC_VALID_KEY);
        if(entry->flags & AUTOC_OWNED_KEY) #{key.dtor("entry->key")};
        if(entry->flags & AUTOC_VALID_VALUE && entry->flags & AUTOC_OWNED_VALUE) #{value.dtor("entry->value")};
      }
    $
    @set.write_exported_declarations(stream, static, inline)
    @set.write_implementations(stream, static)
    stream << %$
      static #{@entry.type}* #{itGetEntryRef}(#{it}*);
      #{define} void #{ctor}(#{type}* self) {
        #{assert}(self);
        #{@set.ctor}(&self->entries);
      }
      #{define} void #{dtor}(#{type}* self) {
        #{assert}(self);
        #{@set.dtor}(&self->entries);
      }
      static int #{putEntryRef}(#{type}* self, #{@entry.type}* entry) {
        int absent;
        #{assert}(self);
        #{assert}(entry);
        if((absent = !#{containsKey}(self, entry->key))) {
          #{@set.put}(&self->entries, *entry);
        }
        return absent;
      }
      #{define} void #{copy}(#{type}* dst, #{type}* src) {
        #{it} it;
        #{assert}(src);
        #{assert}(dst);
        #{ctor}(dst);
        #{itCtor}(&it, src);
        while(#{itMove}(&it)) {
          #{@entry.type}* e = #{itGetEntryRef}(&it);
          #{putEntryRef}(dst, e);
        }
      }
      static int #{containsAllOf}(#{type}* self, #{type}* other) {
        #{it} it;
        #{itCtor}(&it, self);
        while(#{itMove}(&it)) {
          int found = 0;
          #{@entry.type}* e = #{itGetEntryRef}(&it);
          if(#{containsKey}(other, e->key)) {
            #{value.type} other_value = #{get}(other, e->key);
            found = #{value.equal("e->value", "other_value")};
            #{value.dtor("other_value")};
          }
          if(!found) return 0;
        }
        return 1;
      }
      #{define} int #{equal}(#{type}* lt, #{type}* rt) {
        #{assert}(lt);
        #{assert}(rt);
        return #{size}(lt) == #{size}(rt) && #{containsAllOf}(lt, rt) && #{containsAllOf}(rt, lt);
      }
      #{define} size_t #{identify}(#{type}* self) {
        #{assert}(self);
        return #{@set.identify}(&self->entries); /* TODO : make use of the values' hashes */
      }
      #{define} void #{purge}(#{type}* self) {
        #{assert}(self);
        #{@set.purge}(&self->entries);
      }
      #{define} size_t #{size}(#{type}* self) {
        #{assert}(self);
        return #{@set.size}(&self->entries);
      }
      #{define} int #{empty}(#{type}* self) {
        #{assert}(self);
        return #{@set.empty}(&self->entries);
      }
      #{define} int #{containsKey}(#{type}* self, #{key.type} key) {
        int result;
        #{@entry.type} entry;
        #{assert}(self);
        result = #{@set.contains}(&self->entries, entry = #{entryKeyOnlyRef}(&key));
        #{@entry.dtor("entry")};
        return result;
      }
      #{define} #{value.type} #{get}(#{type}* self, #{key.type} key) {
        #{value.type} result;
        #{@entry.type} entry, existing_entry;
        #{assert}(self);
        #{assert}(#{containsKey}(self, key));
        existing_entry = #{@set.get}(&self->entries, entry = #{entryKeyOnlyRef}(&key));
        #{value.copy("result", "existing_entry.value")};
        #{@entry.dtor("existing_entry")};
        #{@entry.dtor("entry")};
        return result;
      }
      #{define} int #{put}(#{type}* self, #{key.type} key, #{value.type} value) {
        int result;
        #{@entry.type} entry;
        #{assert}(self);
        entry = #{entryKeyValueRef}(&key, &value);
        result = #{putEntryRef}(self, &entry);
        #{@entry.dtor("entry")};
        return result;
      }
      #{define} void #{replace}(#{type}* self, #{key.type} key, #{value.type} value) {
        #{@entry.type} entry;
        #{assert}(self);
        entry = #{entryKeyValueRef}(&key, &value);
        #{@set.replace}(&self->entries, entry, entry);
        #{@entry.dtor("entry")};
      }
      #{define} int #{remove}(#{type}* self, #{key.type} key) {
        int removed;
        #{@entry.type} entry;
        #{assert}(self);
        removed = #{@set.remove}(&self->entries, entry = #{entryKeyOnlyRef}(&key));
        #{@entry.dtor("entry")};
        return removed;
      }
      #{define} void #{itCtor}(#{it}* self, #{type}* map) {
        #{assert}(self);
        #{assert}(map);
        #{@set.itCtor}(&self->it, &map->entries);
      }
      #{define} int #{itMove}(#{it}* self) {
        #{assert}(self);
        return #{@set.itMove}(&self->it);
      }
      #{define} #{key.type} #{itGetKey}(#{it}* self) {
        #{@entry.type}* e;
        #{key.type} key;
        #{assert}(self);
        e = #{itGetEntryRef}(self);
        #{key.copy("key", "e->key")};
        return key;
      }
      #{define} #{key.type} #{itGetValue}(#{it}* self) {
        #{@entry.type}* e;
        #{value.type} value;
        #{assert}(self);
        e = #{itGetEntryRef}(self);
        #{assert}(e->flags & AUTOC_VALID_VALUE);
        #{value.copy("value", "e->value")};
        return value;
      }
      static #{@entry.type}* #{itGetEntryRef}(#{it}* self) {
        #{assert}(self);
        return #{@set.itGetRef}(&self->it);
      }
      #undef AUTOC_VALID_VALUE
      #undef AUTOC_VALID_KEY
      #undef AUTOC_OWNED_VALUE
      #undef AUTOC_OWNED_KEY
    $
  end
  
end # HashMap


end # AutoC