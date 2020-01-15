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

    attr_reader :name

    attr_reader :interface, :declaration, :definition

    def initialize(name, sources: 0, size_threshold: 100*1024)
      @name = c_id(name)
      @entities = SortedSet.new
      @interface = Render.new(:interface)
      @declaration = Render.new(:declaration)
      @definition = Render.new(:definition)
      @sources = sources
      @threshold = size_threshold
    end

    def <<(entity)
      @entities.merge(entity.dependencies)
      @entities << entity
      self
    end

    private

    def compute_sources!
      if @sources.zero?
        size = 0
        @entities.each do |e|
          declaration[e].each {|x| size += x.length}
          definition[e].each {|x| size += x.length}
        end
        @sources = (size / @threshold + 1).truncate
      end
    end

    def new_header
      Header.new(self)
    end

    def new_source
      Source.new(self)
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

    attr_reader :module

    def initialize(m)
      @module = m
    end

    def prologue(stream)
      stream << %~
        #ifndef #{self.module.name}_autoc_h
        #define #{self.module.name}_autoc_h
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

    attr_reader :module

    def initialize(m)
      @module = m
      @entities = SortedSet.new
    end

    def <<(entity)
      @entities.merge(entity.dependencies)
      @entities << entity
      @size = nil
      self
    end

    def size
      @size ||= begin
                  size = 0
                  @entities.each do |e|
                    self.module.declaration[e].each {|x| size += x.length}
                    self.module.definition[e].each {|x| size += x.length}
                  end
                  size
                end
    end

    def <=>(other)
      size <=> other.size
    end

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
          dependencies.include?(other) ? -1 : +1
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