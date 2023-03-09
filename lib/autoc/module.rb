# frozen_string_literal: true


require 'set'
require 'digest'

require 'autoc'


module AutoC


  class Module

    # @private
    module EntityContainer

      def entities = @entities ||= ::Set.new

      def <<(entity)
        entities << entity
        self
      end

    end # EntityContainer

    # @private
    class Builder < ::Array

      attr_reader :complexity

      def initialize
        @complexity = 0
        super
      end

      def <<(obj)
        @complexity += (s = obj.to_s).size
        super(s)
      end

    end

    include EntityContainer

    CAP = "/* Automagically generated by AutoC #{AutoC::VERSION} */"

    attr_reader :name

    attr_accessor :source_count

    attr_accessor :source_threshold

    def initialize(name) = @name = name

    def header = @header ||= Header.new(self)

    def sources = @sources ||= (1..source_count).collect { |i| Source.new(self, i) }

    def digests = @digests ||= State.new(self).read

    def render
      distribute_entities
      header.render
      sources.each(&:render)
      State.new(self).collect.write
      self
    end

    def total_entities
      @total_entities ||= begin
        set = ::Set.new
        entities.each { |e| set.merge(e.total_references) }
        set
      end
    end

    private def distribute_entities
      header.entities.merge(total_entities)
      if source_count.nil?
        @source_count = source_threshold.nil? ? 1 : (total_entities.sum(&:complexity).to_f / source_threshold).ceil
      end
      total_entities.each do |e|
        sources.sort! { |lt, rt| lt.complexity <=> rt.complexity }
        sources.first << e
      end
    end

    def self.render(name, &code)
      m = self.new(name)
      yield(m) if block_given?
      m.render
    end

  end # Module


  # @private
  class Module::State < ::Hash

    attr_reader :module

    def file_name = "#{self.module.name}.state"

    def initialize(m)
      super
      @module = m
    end

    def collect
      self[self.module.header.file_name] = self.module.header.digest
      self.module.sources.each { |source| self[source.file_name] = source.digest }
      self
    end

    def read
      if File.exist?(file_name)
        # It's OK not to have this file but if it exists it must have proper contents
        io = File.open(file_name, 'rt', chomp: true)
        begin
          hash = {}
          io.readlines.each do |x|
            raise 'improper state file format' if (/\s*([^\s]+)\s+\*(.*)/ =~ x).nil?
            hash[$2] = $1
          end
          update(hash)
        ensure
          io.close
        end
      end
      self
    end

    def write
      io = File.open(file_name, 'wt')
      begin
        begin
          each { |file_name, digest| io << "#{digest} *#{file_name}\n" }
        ensure
          io.close
        end
      rescue
        File.unlink(file_name) # Delete improperly rendered state file
        raise
      end
      self
    end

  end # State


  # @private
  class Module::StreamFile < File

    def digest = @digest.hexdigest

    def initialize(*args, **kws)
      super(*args, **kws)
      @digest = Digest::MD5.new
    end

    def <<(data)
      super(data)
      @digest.update(data)
      self
    end

  end # StreamFile


  # @private
  module Module::SmartRenderer

    # def render_contents(stream)

    attr_reader :digest

    def render
      io = stream
      _file_name = io.path # Memorize temporary file name
      begin
        begin
          render_contents(io)
          @digest = io.digest
        ensure
          io.close
        end
      rescue
        File.unlink(_file_name) # Remove improperly rendered temporary file
        raise
      else
        if !File.exist?(file_name) || self.module.digests[file_name] != digest
          File.rename(_file_name, file_name) # Rendered temporary has different digest - replace original permanent file with it
        else
          File.unlink(_file_name) # New temporary has the same digest as permanent - no need to replace the latter, delete the temporary instead
        end
      end
    end

  end # SmartRenderer


  class Module::Header

    include Module::EntityContainer

    include Module::SmartRenderer

    attr_reader :module

    def file_name = @file_name ||= "#{self.module.name}_auto.h"

    def tag = "#{self.module.name}_auto_h".upcase

    def initialize(m) = @module = m

  private

    def render_contents(stream)
      render_prologue(stream)
      entities.to_a.sort.each { |e| e.interface.each { |x| stream << x } }
      render_epilogue(stream)
    end

    def render_prologue(stream)
      stream << %{
        #{Module::CAP}
        #ifndef #{tag}
        #define #{tag}
      }
    end

    def render_epilogue(stream)
      stream << %{
        #endif
      }
    end

    def stream = @stream ||= Module::StreamFile.new(file_name+'~', 'wt')

  end # Header


  class Module::Source

    include Module::EntityContainer

    include Module::SmartRenderer

    attr_reader :module

    attr_reader :complexity

    attr_reader :index

    def file_name = self.module.source_count < 2 ? "#{self.module.name}_auto.c" : "#{self.module.name}_auto#{index}.c"

    def initialize(m, index)
      @module = m
      @complexity = 0
      @index = index
    end

    def <<(entity)
      @complexity += entity.complexity unless entities.include?(entity)
      super
    end

  private

    def render_contents(stream)
      render_prologue(stream)
      total_entities = ::Set.new
      entities.each { |e| total_entities.merge(e.total_references) }
      total_entities.to_a.sort.each { |e| e.forward_declarations.each { |x| stream << x } }
      entities.to_a.sort.each { |e| e.implementation.each { |x| stream << x } }
    end

    def render_prologue(stream)
      stream << %{
        #{Module::CAP}
        #include "#{self.module.header.file_name}"
      }
    end

    def stream = @stream ||= Module::StreamFile.new(file_name+'~', 'wt')

  end # Source


  module Entity

    include ::Comparable

    # A set of the entity's immediate references which, unlike dependencies, do not enforce the entities relative ordering
    def references = @references ||= ReferenceSet.new

    # Return the entire entity's reference set staring with self
    def total_references = @total_references ||= collect_references(::Set.new)

    # A set of the entity's immediate dependencies which enforce the entities relative ordering
    def dependencies = @dependencies ||= DependencySet.new(self)

    # Return the entire entity's dependency set staring with self
    def total_dependencies = @total_dependencies ||= collect_dependencies(::Set.new)

    protected def collect_references(set)
      unless set.include?(self)
        set << self
        references.each { |x| x.collect_references(set) }
      end
      set
    end

    protected def collect_dependencies(set)
      unless set.include?(self)
        set << self
        dependencies.each { |x| x.collect_dependencies(set) }
      end
      set
    end

    def <=>(other) = position <=> other.position

    # Compute the entity's relative position with respect to its dependencies
    def position = @position ||= begin
      p = 0
      # This code goes into infinite recursion on circular dependency
      # which must be resolved manually with Entity#references
      total_dependencies.each do |d|
        unless equal?(d)
          dp = d.position
          p = dp if p < dp # p <- max(p, dp)
        end
      end
      p + 1 # Arrange entity to follow all its dependencies
    end

    def complexity = forward_declarations.complexity + implementation.complexity # Interface part is not considered as it is shared across the sources

    def interface
      @interface ||= begin
        render_interface(stream = Module::Builder.new)
        stream
      end
    end

    def forward_declarations
      @forward_declarations ||= begin
        render_forward_declarations(stream = Module::Builder.new)
        stream
      end
    end

    def implementation
      @implementation ||= begin
        render_implementation(stream = Module::Builder.new)
        stream
      end
    end
  
  private

    ### Overridable rendering methods

    def render_interface(stream) = nil

    def render_forward_declarations(stream) = nil

    def render_implementation(stream) = nil

  end # Entity


  Entity::ReferenceSet = ::Set


  # @private
  class Entity::DependencySet < ::Set

    def initialize(entity)
      super()
      @entity = entity
    end

    def <<(x)
      @entity.references << x # Each dependency is also registered as a reference
      super
    end

  end # DependencySet


  # Helper class to represent plain C side code block
  class Code

    include Entity

    def initialize(interface: nil, implementation: nil, definitions: nil)
      @interface_ = interface
      @definitions_ = definitions
      @implementation_ = implementation
    end

    def inspect = "... <#{self.class}>"

  private

    def render_interface(stream)
      stream << @interface_ unless @interface_.nil?
    end

    def render_implementation(stream)
      stream << @implementation_ unless @implementation_.nil?
    end

    def render_forward_declarations(stream)
      stream << @definitions_ unless @definitions_.nil?
    end

  end # Code


  # Helper class to inject a system-wide header into the C side interface part of the module
  class SystemHeader < AutoC::Code
    def initialize(header)
      super interface: %{
        #include <#{header}>
      }
    end
  end # SystemHeader


end