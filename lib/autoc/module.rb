require 'set'


module AutoC


  #
  class Module

    # Convert obj to string and return it.
    # Throw NameError if resulting string is not a valid C identifier.
    def self.c_id(obj)
      obj = obj.to_s
      raise NameError, "`#{obj}` is not a valid C identifier" if (/^[_a-zA-Z]\w*$/ =~ obj).nil?
      obj
    end

    attr_reader :name, :entities, :total_entities

    attr_reader :interface, :declarations, :definitions

    def initialize(name, source_count: 0, size_threshold: 100*1024)
      @name = Module.c_id(name)
      @entities = Set.new
      @total_entities = Set.new
      @interface = Render.new(:interface)
      @declarations = Render.new(:declarations)
      @definitions = Render.new(:definitions)
      @source_count = source_count
      @threshold = size_threshold
      raise ArgumentError, 'source count must be a non-negative number' if @source_count.negative?
    end

    def <<(entity)
      @entities << entity
      @total_entities.merge(entity.total_entities)
      self
    end

    attr_reader :header, :sources

    def self.render!(name, &code)
      m = self.new(name, source_count: 1)
      yield(m)
      m.render!
    end

    def render!
      setup_header!
      setup_sources!
      distribute_entities!
      header.render!
      sources.each {|s| s.render!}
    end

    def source_size(entities)
      size = 0
      total_entities = entities.dup
      entities.each do |e|
        definitions[e].each {|x| size += x.length}
        total_entities.merge(e.dependencies)
      end
      total_entities.each do |e|
        declarations[e].each {|x| size += x.length}
      end
      size
    end

    private

    def required_sources
      @source_count.zero? ? (source_size(@entities) / @threshold + 1).truncate : @source_count
    end

    def new_header(tag)
      Header.new(self, tag)
    end

    def new_source(tag)
      Source.new(self, tag)
    end

    def setup_header!
      @header = new_header(name)
    end

    def setup_sources!
      @sources = Set.new
      if (n = required_sources) == 1
        sources << new_source(name)
      else
        (1..n).each {|i| sources << new_source("#{name}#{i}")}
      end
    end

    def distribute_entities!
      srcs = sources.to_a
      total_entities.each do |e|
        srcs.sort!
        srcs.first << e # Put into the least populated source
      end
    end
  end # Module


  # :nodoc:
  class Render

    def initialize(meth)
      @render = {}
      @meth = meth
    end

    def [](entity)
      entity.send(@meth, x = []) if (x = @render[entity]).nil?
      @render[entity] = x
    end

  end # Render


  #
  class Module::Header

    attr_reader :module, :tag

    def initialize(m, tag)
      @module = m
      @tag = tag
    end

    def file_name
      @file_name ||= "#{tag}_auto.h"
    end

    def render!
      stream = new_stream
      begin
        prologue(stream)
        SortedSet.new(self.module.total_entities).each do |e|
          self.module.interface[e].each {|x| stream << x}
        end
        epilogue(stream)
      ensure
        stream.close
      end
    end

    private

    def new_stream
      File.new(file_name, 'w')
    end

    def prologue(stream)
      stream << %~
        #ifndef #{tag}_auto_h
        #define #{tag}_auto_h
      ~
    end

    def epilogue(stream)
      stream << %~
        #endif
      ~
    end

  end # Header


  #
  class Module::Source

    include Comparable

    attr_reader :module, :tag

    def initialize(m, tag)
      @module = m
      @tag = tag
      @entities = Set.new
    end

    def file_name
      @file_name ||= "#{tag}_auto.c"
    end

    def <<(entity)
      unless @entities.include?(entity)
        @entities << entity
        @size = nil
      end
      self
    end

    def size
      @size ||= self.module.source_size(@entities)
    end

    def <=>(other)
      size <=> other.size
    end

    def render!
      stream = new_stream
      begin
        prologue(stream)
        entities = SortedSet.new(@entities)
        total_entities = entities.dup
        entities.each {|e| total_entities.merge(e.dependencies)}
        total_entities.each do |e|
          self.module.declarations[e].each {|x| stream << x}
        end
        entities.each do |e|
          self.module.definitions[e].each {|x| stream << x}
        end
        epilogue(stream)
      ensure
        stream.close
      end
    end

    private

    def new_stream
      File.new(file_name, 'w')
    end

    def prologue(stream)
      stream << %~
        #include "#{self.module.header.file_name}"
      ~
    end

    def epilogue(stream) end

  end # Source


  #
  module Module::Entity

    EMPTY_SET = Set.new.freeze

    include Comparable

    # Return a set of immediate dependencies of self.
    def dependencies
      EMPTY_SET
    end

    # Return a set of all entities including self and transient dependencies.
    def total_entities
      @total_entities ||= merge_total_dependencies(Set[self]).freeze
    end

    # Merge a set of all entities including self as well as self's transient dependencies into specified set.
    def merge_total_dependencies(set)
      dependencies.each do |d|
        unless set.include?(d)
          d.merge_total_dependencies(set)
          set << d
        end
      end
      set
    end

    #
    def <=>(other)
      if other.is_a?(Module::Entity)
        if self == other
          0
        else
          total_entities.include?(other) ? +1 : -1
        end
      else
        nil
      end
    end

    #
    def interface(stream) end

    #
    def declarations(stream) end

    #
    def definitions(stream) end

  end # Entity


  #
  class Code

    include Module::Entity

    def self.interface(s)
      Code.new(interface: s)
    end

    def initialize(interface: nil, declarations: nil, definitions: nil)
      @interface = interface
      @declarations = declarations
      @definitions = definitions
    end

    def interface(stream)
      super
      stream << @interface unless @interface.nil?
    end

    def definitions(stream)
      super
      stream << @definitions unless @definitions.nil?
    end

    def declarations(stream)
      super
      stream << @declarations unless @declarations.nil?
    end

  end # Code


end # AutoC