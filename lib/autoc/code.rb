require "set"


module AutoC


# class Entity
#   def entities()
#   def priority()
#   def source_size()
#   def attach(source)
#   def write_intf(stream)
#   def write_defs(stream)
#   def write_decls(stream)
#   def hash()
#   def eql?(other)
# end


# Convert obj to string and return it.
# Throw NameError is resulting string is not a valid C identifier.
def self.c_id(obj)
  obj = obj.to_s
  #raise NameError.new("#{obj} is not a valid C identifier", obj) if (/^[_a-zA-Z]\w*$/ =~ obj).nil?
  obj
end


# TODO min/max Fixnums
module Priority
  DEFAULT = 0
  MIN = -1000
  MAX = +1000
end


# A no-op entity implementation with reasonable defaults
class Code
  def entities; [] end
  def priority
    if entities.empty?
      Priority::DEFAULT
    else
      result = Priority::DEFAULT
      entities.each do |e|
        ep = e.priority
        result = ep if result > ep
      end
      result-1
    end
  end
  def source_size
    s = String.new
    write_decls(s)
    write_defs(s)
    s.size
  end
  def attach(source) source << self if source.smallest? end
  def write_intf(stream) end
  def write_defs(stream) end
  def write_decls(stream) end
end # Code


class Module

  def self.generate!(name, &block)
    m = self.new(name)
    block.call(m)
    m.generate!
  end
  
  attr_reader :name, :header, :smallest_source, :main_source

  def initialize(name)
    @entities = Set.new
    @source_size_threshold = 0
    @name = name.to_s # TODO validate
  end
  
  def <<(obj)
    obj.entities.each {|e| self << e} unless @entities.add?(obj).nil?
    self
  end

  def new_header
    Header.new(self)
  end
  
  def new_source(index)
    Source.new(self, index)
  end

  def source_count=(count)
    @source_count = count
  end

  def generate!
    @header = new_header
    @sources = []
    (1..source_count).each {|i| @sources << new_source(i)}
    @main_source = @sources.first
    @smallest_source = @main_source
    # It appears that computing the size of a source might be a fairly expensive operation so do it only when necessary
    refresh_smallest_source = source_count > 1
    @entities.each do |e|
      @header << e
      @smallest_source = @sources.sort_by {|s| s.size}.first if refresh_smallest_source
      @sources.each {|s| e.attach(s)}
    end
    @header.generate
    @sources.each {|s| s.generate}
  end

  def source_count
    if @source_count.nil?
      total = 0
      @entities.each {|e| total += e.source_size}
      count = @source_size_threshold > 0 ? (total/@source_size_threshold + 1) : 1
      @source_count = count > 0 ? count : 1
    else
      @source_count
    end
  end

end # Module


def self.priority_sort(entities, reverse = false)
  list = entities.to_a.sort! {|a,b| a.priority <=> b.priority}
  list.reverse! unless reverse
  list
end # priority_sort


class Module::File

  attr_reader :entities

  # def new_stream()

  # def write(stream)

  def initialize(m)
    @entities = Set.new
    @module = m
  end

  def generate
    stream = new_stream
    begin
      write(stream)
    ensure
      stream.close
    end
  end

  def <<(e)
    @entities << e
    self
  end

end # File


class Module::Header < Module::File
  
  attr_reader :file_name
  
  def initialize(*args)
    super
    @file_name = "#{@module.name.downcase}_auto.h"
    @guard_macro = "#{@module.name.upcase}_AUTO_H"
  end
  
  def new_stream
    ::File.new(@file_name, "w")
  end
  
  def write(stream)
    stream << %$
      /* AUTOMATICALLY GENERATED HEADER FILE. DO NOT MODIFY. */
      #ifndef #{@guard_macro}
      #define #{@guard_macro}
    $
    AutoC.priority_sort(entities).each {|e| e.write_intf(stream)}
    stream << %$
      #endif
    $
  end
  
end # Header


class Module::Source < Module::File

  attr_reader :index, :file_name

  def initialize(m, i)
    super(m)
    @index = i
    @file_name = @module.source_count > 1 ? "#{@module.name.downcase}_auto#{index}.c" : "#{@module.name.downcase}_auto.c"
  end

  def main?
    equal?(@module.main_source)
  end

  def smallest?
    equal?(@module.smallest_source)
  end

  def size
    size = 0
    @entities.each {|e| size += e.source_size}
    size
  end

  def new_stream
    ::File.new(@file_name, "w")
  end
  
  def write(stream)
    stream << %$
      /* AUTOMATICALLY GENERATED SOURCE FILE. DO NOT MODIFY. */
      #include "#{@module.header.file_name}"
    $
    sorted = AutoC.priority_sort(entities)
    sorted.each {|e| e.write_decls(stream)}
    sorted.each {|e| e.write_defs(stream)}
  end
  
end # Source


end # AutoC