require "autoc/collection"
require "autoc/collection/tree_set"


module AutoC

  
=begin

TreeMap< *_K_* => *_E_* > is a tree-based ordered random access container holding unique keys with each key having an element bound to it.

TreeMap is backed by {AutoC::TreeSet} container.

The collection's C++ counterpart is +std::map<>+ template class.

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
Stored keys and values are destroyed as well by calling the respective destructors.

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

WARNING: +self+ *must* contain such key otherwise the behavior is undefined. See ~type~ContainsKey().

|*_E_* ~type~PeekLowestElement(*_Type_* * +self+)
|
Return a _copy_ of an element bound to the lowest key in +self+.

WARNING: +self+ *must not* be empty otherwise the behavior is undefined. See ~type~Empty().

|*_K_* ~type~PeekLowestKey(*_Type_* * +self+)
|
Return a _copy_ of the lowest key in +self+.

WARNING: +self+ *must not* be empty otherwise the behavior is undefined. See ~type~Empty().

|*_E_* ~type~PeekHighestElement(*_Type_* * +self+)
|
Return a _copy_ of an element bound to the highest key in +self+.

WARNING: +self+ *must not* be empty otherwise the behavior is undefined. See ~type~Empty().

|*_K_* ~type~PeekHighestKey(*_Type_* * +self+)
|
Return a _copy_ of the highest key in +self+.

WARNING: +self+ *must not* be empty otherwise the behavior is undefined. See ~type~Empty().

|*_void_* ~type~Purge(*_Type_* * +self+)
|
Remove and destroy all keys and elements stored in +self+.

|*_int_* ~type~Put(*_Type_* * +self+, *_K_* +key+, *_E_* +value+)
|
Put a _copy_ of the element +value+ bound to a _copy_ of the key +key+ into +self+
*only if* there is no such key in +self+ which is considered equal to +key+.

Return non-zero value on successful put and zero value otherwise.

|*_int_* ~type~Replace(*_Type_* * +self+, *_K_* +key+, *_E_* +value+)
|
If +self+ contains a key which is considered equal to the key +key+,
remove and destroy that key along with an element bound to it
and put a new pair built of the _copies_ of +key+ and +value+,
otherwise no nothing.

Return non-zero value if the replacement was actually performed and zero value otherwise.

|*_int_* ~type~Remove(*_Type_* * +self+, *_K_* +key+)
|
Remove and destroy a key which is considered equal to the key +key+.
Destroy an element bound to that key.

Return non-zero value on successful key/element pair removal and zero value otherwise.

|*_size_t_* ~type~Size(*_Type_* * +self+)
|
Return number of key/element pairs stored in +self+.
|===

=== Iteration

[cols=2*]
|===
|*_void_* ~it~Ctor(*_IteratorType_* * +it+, *_Type_* * +self+)
|
Create a new ascending iterator +it+ on map +self+. See ~it~CtorEx().

NOTE: Previous contents of +it+ is overwritten.

|*_void_* ~it~CtorEx(*_IteratorType_* * +it+, *_Type_* * +self+, *_int_* +ascending+)
|
Create a new iterator +it+ on map +self+.
Non-zero value of +ascending+ specifies an ascending (+lowest to highest key traversal+) iterator, zero value specifies a descending (+highest to lowest key traversal+) iterator.

NOTE: Previous contents of +it+ is overwritten.

|*_int_* ~it~Move(*_IteratorType_* * +it+)
|
Advance iterator position of +it+ *and* return non-zero value if new position is valid and zero value otherwise.

|*_K_* ~it~GetKey(*_IteratorType_* * +it+)
|
Return a _copy_ of the key from a key/value pair pointed to by the iterator +it+.

WARNING: current position *must* be valid otherwise the behavior is undefined. See ~it~Move().

|*_E_* ~it~GetElement(*_IteratorType_* * +it+)
|
Return a _copy_ of the element from a key/element pair pointed to by the iterator +it+.

WARNING: current position *must* be valid otherwise the behavior is undefined. See ~it~Move().

|*_E_* ~it~Get(*_IteratorType_* * +it+)
|
Alias for ~it~GetElement().
|===

=end
class TreeMap < Collection
  
  attr_reader :key

  alias :value :element
  
  def hash; super ^ key.hash end
  
  def ==(other) super && key == other.key end
  
  alias :eql? :==

  def entities; super << key end
  
  def initialize(type, key_type, value_type, visibility = :public)
    super(type, value_type, visibility)
    @key = Type.coerce(key_type)
    @entry = UserDefinedType.new(:type => entry, :identify => entryIdentify, :equal => entryEqual, :less => entryLess, :copy => entryCopy, :dtor => entryDtor)
    @set = TreeSet.new(set, @entry, :static)
    element_requirement(value)
    key_requirement(key)
  end

  def copyable?; super && key.copyable? end
  
  def comparable?; super && key.comparable? end
  
  def hashable?; super && key.hashable? end
  
  def write_intf_types(stream)
    super
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
    @set.write_intf_types(stream)
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

  def write_intf_decls(stream, declare, define)
    super
    stream << %$
      #{declare} #{ctor.declaration};
      #{declare} #{dtor.declaration};
      #{declare} #{copy.declaration};
      #{declare} #{equal.declaration};
      #{declare} #{identify.declaration};
      #{declare} void #{purge}(#{type_ref});
      #{declare} size_t #{size}(#{type_ref});
      #define #{empty}(self) (#{size}(self) == 0)
      #{declare} int #{containsKey}(#{type_ref}, #{key.type});
      #{declare} #{value.type} #{get}(#{type_ref}, #{key.type});
      #{declare} #{key.type} #{peekLowestKey}(#{type_ref});
      #{declare} #{value.type} #{peekLowestElement}(#{type_ref});
      #{declare} #{key.type} #{peekHighestKey}(#{type_ref});
      #{declare} #{value.type} #{peekHighestElement}(#{type_ref});
      #{declare} int #{put}(#{type_ref}, #{key.type}, #{value.type});
      #{declare} int #{replace}(#{type_ref}, #{key.type}, #{value.type});
      #{declare} int #{remove}(#{type_ref}, #{key.type});
      #define #{itCtor}(self, type) #{itCtorEx}(self, type, 1)
      #{declare} void #{itCtorEx}(#{it_ref}, #{type_ref}, int);
      #{declare} int #{itMove}(#{it_ref});
      #{declare} #{key.type} #{itGetKey}(#{it_ref});
      #{declare} #{value.type} #{itGetElement}(#{it_ref});
      #define #{itGet}(it) #{itGetElement}(it)
    $
  end

  def write_impls(stream, define)
    super
    stream << %$
      #define #{validValue} 1
      #define #{validKey} 2
      #define #{ownedValue} 4
      #define #{ownedKey} 8
      static #{@entry.type} #{entryKeyOnlyRef}(#{key.type_ref} key) {
        #{@entry.type} entry;
        entry.key = *key;
        entry.flags = #{validKey};
        return entry;
      }
      static #{@entry.type} #{entryKeyValueRef}(#{key.type_ref} key, #{value.type_ref} value) {
        #{@entry.type} entry;
        entry.key = *key;
        entry.value = *value;
        entry.flags = (#{validKey} | #{validValue});
        return entry;
      }
      #define #{entryEqual}(lt, rt) #{entryEqualRef}(&lt, &rt)
      static int #{entryEqualRef}(#{@entry.type}* lt, #{@entry.type}* rt) {
        return #{key.equal("lt->key", "rt->key")};
      }
      #define #{entryLess}(lt, rt) #{entryLessRef}(&lt, &rt)
      static int #{entryLessRef}(#{@entry.type}* lt, #{@entry.type}* rt) {
        return #{key.less("lt->key", "rt->key")};
      }
      #define #{entryIdentify}(obj) #{entryIdentifyRef}(&obj)
      static size_t #{entryIdentifyRef}(#{@entry.type}* entry) {
        return #{key.identify("entry->key")};
      }
      #define #{entryCopy}(dst, src) #{entryCopyRef}(&dst, &src)
      static void #{entryCopyRef}(#{@entry.type_ref} dst, #{@entry.type_ref} src) {
        #{assert}(src->flags & #{validKey});
        dst->flags = (#{validKey} | #{ownedKey});
        #{key.copy("dst->key", "src->key")};
        if(src->flags & #{validValue}) {
          dst->flags |= (#{validValue} | #{ownedValue});
          #{value.copy("dst->value", "src->value")};
        }
      }
      #define #{entryDtor}(obj) #{entryDtorRef}(&obj)
      static void #{entryDtorRef}(#{@entry.type}* entry) {
        #{assert}(entry->flags & #{validKey});
        if(entry->flags & #{ownedKey}) #{key.dtor("entry->key")};
        if(entry->flags & #{validValue} && entry->flags & #{ownedValue}) #{value.dtor("entry->value")};
      }
      static #{@entry.type_ref} #{itGetEntryRef}(#{it_ref});
      static int #{containsAllOf}(#{type_ref} self, #{type_ref} other) {
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
    $
    @set.write_intf_decls(stream, static, inline)
    @set.write_impls(stream, static)
    stream << %$
      #{define} #{ctor.definition} {
        #{assert}(self);
        #{@set.ctor}(&self->entries);
      }
      #{define} #{dtor.definition} {
        #{assert}(self);
        #{@set.dtor}(&self->entries);
      }
      static int #{putEntryRef}(#{type_ref} self, #{@entry.type_ref} entry) {
        int absent;
        #{assert}(self);
        #{assert}(entry);
        absent = !#{containsKey}(self, entry->key);
        if(absent) #{@set.put}(&self->entries, *entry);
        return absent;
      }
      #{define} #{copy.definition} {
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
      #{define} #{equal.definition} {
        #{assert}(lt);
        #{assert}(rt);
        return #{size}(lt) == #{size}(rt) && #{containsAllOf}(lt, rt) && #{containsAllOf}(rt, lt);
      }
      #{define} #{identify.definition} {
        #{assert}(self);
        return #{@set.identify}(&self->entries); /* TODO : make use of the values' hashes */
      }
      #{define} void #{purge}(#{type_ref} self) {
        #{assert}(self);
        #{@set.purge}(&self->entries);
      }
      #{define} size_t #{size}(#{type_ref} self) {
        #{assert}(self);
        return #{@set.size}(&self->entries);
      }
      #{define} int #{containsKey}(#{type_ref} self, #{key.type} key) {
        int result;
        #{@entry.type} entry;
        #{assert}(self);
        result = #{@set.contains}(&self->entries, entry = #{entryKeyOnlyRef}(&key));
        #{@entry.dtor("entry")};
        return result;
      }
      #{define} #{value.type} #{get}(#{type_ref} self, #{key.type} key) {
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
      #{define} #{key.type} #{peekLowestKey}(#{type_ref} self) {
        #{key.type} result;
        #{@set.node}* node;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        node = #{@set.lowestNode}(&self->entries);
        #{assert}(node);
        #{key.copy("result", "node->element.key")};
        return result;
      }
      #{define} #{value.type} #{peekLowestElement}(#{type_ref} self) {
        #{value.type} result;
        #{@set.node}* node;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        node = #{@set.lowestNode}(&self->entries);
        #{assert}(node);
        #{element.copy("result", "node->element.value")};
        return result;
      }
      #{define} #{key.type} #{peekHighestKey}(#{type_ref} self) {
        #{key.type} result;
        #{@set.node}* node;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        node = #{@set.highestNode}(&self->entries);
        #{assert}(node);
        #{key.copy("result", "node->element.key")};
        return result;
      }
      #{define} #{value.type} #{peekHighestElement}(#{type_ref} self) {
        #{value.type} result;
        #{@set.node}* node;
        #{assert}(self);
        #{assert}(!#{empty}(self));
        node = #{@set.highestNode}(&self->entries);
        #{assert}(node);
        #{element.copy("result", "node->element.value")};
        return result;
      }
      #{define} int #{put}(#{type_ref} self, #{key.type} key, #{value.type} value) {
        int result;
        #{@entry.type} entry;
        #{assert}(self);
        entry = #{entryKeyValueRef}(&key, &value);
        result = #{putEntryRef}(self, &entry);
        #{@entry.dtor("entry")};
        return result;
      }
      #{define} int #{replace}(#{type_ref} self, #{key.type} key, #{value.type} value) {
        int result;
        #{@entry.type} entry;
        #{assert}(self);
        entry = #{entryKeyValueRef}(&key, &value);
        result = #{@set.replace}(&self->entries, entry);
        #{@entry.dtor("entry")};
        return result;
      }
      #{define} int #{remove}(#{type_ref} self, #{key.type} key) {
        int result;
        #{@entry.type} entry;
        #{assert}(self);
        result = #{@set.remove}(&self->entries, entry = #{entryKeyOnlyRef}(&key));
        #{@entry.dtor("entry")};
        return result;
      }
      #{define} void #{itCtorEx}(#{it_ref} self, #{type_ref} map, int ascending) {
        #{assert}(self);
        #{assert}(map);
        #{@set.itCtorEx}(&self->it, &map->entries, ascending);
      }
      #{define} int #{itMove}(#{it_ref} self) {
        #{assert}(self);
        return #{@set.itMove}(&self->it);
      }
      #{define} #{key.type} #{itGetKey}(#{it_ref} self) {
        #{@entry.type_ref} e;
        #{key.type} key;
        #{assert}(self);
        e = #{itGetEntryRef}(self);
        #{key.copy("key", "e->key")};
        return key;
      }
      #{define} #{value.type} #{itGetElement}(#{it_ref} self) {
        #{@entry.type_ref} e;
        #{value.type} value;
        #{assert}(self);
        e = #{itGetEntryRef}(self);
        #{assert}(e->flags & #{validValue});
        #{value.copy("value", "e->value")};
        return value;
      }
      static #{@entry.type_ref} #{itGetEntryRef}(#{it_ref} self) {
        #{assert}(self);
        return #{@set.itGetRef}(&self->it);
      }
    $
  end
  
end # TreeMap


end # AutoC