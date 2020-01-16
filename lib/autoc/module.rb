require 'set'


module AutoC


  #
  class Module

    # Convert obj to string and return it.
    # Throw NameError if resulting string is not a valid C identifier.
    def self.c_id(obj)
      obj = obj.to_s
      raise NameError.new("'#{obj}' is not a valid C identifier", obj) if (/^[_a-zA-Z]\w*$/ =~ obj).nil?
      obj
    end

    attr_reader :name, :entities, :total_entities

    attr_reader :interface, :declaration, :definition

    def initialize(name, sources: 0, size_threshold: 100*1024)
      @name = c_id(name)
      @entities = Set.new
      @total_entities = Set.new
      @interface = Render.new(:interface)
      @declaration = Render.new(:declaration)
      @definition = Render.new(:definition)
      @sources = sources
      @threshold = size_threshold
      raise ArgumentError, 'sources must be a non-negative number' if @sources.negative?
    end

    def <<(entity)
      @total_entities << @entities << entity
      @total_entities.merge(entity.dependencies)
      self
    end

    attr_reader :header, :sources

    def render!
      setup_header!
      setup_sources!
      header.render!
    end

    def source_size(entities)
      size = 0
      total_entities = entities.dup
      entities.each do |e|
        definition[e].each {|x| size += x.length}
        total_entities.merge(e.dependencies)
      end
      total_entities.each do |e|
        declaration[e].each {|x| size += x.length}
      end
      size
    end

    private

    def required_sources
      (source_size(@entities) / @threshold + 1).truncate if @sources.zero?
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
        @sources << new_source(name)
      else
        (1..n).each {|i| @sources << new_source("#{name}#{i}")}
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
      if (x = @render[entity]).nil?
        entity.send(@meth, x = [])
        @render[entity] = x
      else
        x
      end
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
          self.module.declaration[e].each {|x| stream << x}
        end
        entities.each do |e|
          self.module.definition[e].each {|x| stream << x}
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

    EmptySet = Set.new.freeze

    include Comparable

    def dependencies
      EmptySet
    end

    def <=>(other)
      if other.is_a?(Entity)
        if self == other
          0
        else
          -(dependencies.include?(other) ? -1 : +1) # Negate the value as we need to yield sequence in descending order
        end
      else
        nil
      end
    end

    #
    def interface(stream) end

    #
    def declaration(stream) end

    #
    def definition(stream) end

  end # Entity


end # AutoC