require "autoc/collection"
require "autoc/collection/hash_set"


module AutoC

  
class HashMap < Collection
  
  attr_reader :key

  alias :value :element
  
  def entities; super + [key] end
  
  def initialize(type, key_type, value_type, visibility = :public)
    super(type, value_type, visibility)
    @key = Collection.coerce(key_type)
    @entry = UserDefinedType.new(:type => entry, :identify => entryIdentify, :equal => entryEqual, :copy => entryCopy, :dtor => entryDtor)
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
      static size_t #{entryIdentify}(#{@entry.type} entry) {
        return #{key.identify("entry.key")};
      }
      static int #{entryEqual}(#{@entry.type} lt, #{@entry.type} rt) {
        return #{key.equal("lt.key", "rt.key")};
      }
      #define #{entryCopy}(dst, src) #{entryCopy}(&dst, &src)
      static void #{entryCopy}(#{@entry.type}* dst, #{@entry.type}* src) {
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