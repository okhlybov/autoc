# frozen_string_literal: true


require 'set'
require 'sorted_set'
require 'autoc'


module AutoC


  module EntityContainer

    def entities = @entities ||= ::Set.new

    def <<(entity)
      entities << entity
      self
    end

  end


  class Module

    # :nodoc:
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

    attr_reader :source_count

    def initialize(name) = @name = name

    def header = @header ||= Header.new(self)

    def sources = @sources ||= (1..source_count).collect { |i| Source.new(self, i) }

    def render
      distribute_entities
      header.render
      sources.each(&:render)
    end

    private def distribute_entities
      total_entities = ::Set.new
      entities.each { |e| total_entities.merge(e.total_dependencies) }
      header.entities.merge(total_entities)
      if @source_count.nil?
        if @source_complexity_threshold.nil?
          @source_count = 1
        else
          @source_count = (total_entities.sum(&:complexity).to_f / @source_complexity_threshold).ceil
        end
      end
      total_entities.each do |e|
        sources.sort! { |lt, rt| lt.complexity <=> rt.complexity }
        sources.first << e
      end
    end

    def self.render(name, &code)
      m = Module.new(name)
      yield(m) if block_given?
      m.render
    end
  end


  class Module::Header

    include EntityContainer

    attr_reader :module

    def file_name = @file_name ||= "#{self.module.name}_auto.h"

    def initialize(m)
      @module = m
      @tag = "#{self.module.name}_auto_h".upcase
    end

    def render
      s = stream
      prologue(s)
      ::SortedSet.new(entities).each { |e| e.interface.each { |x| s << x } }
      epilogue(s)
    ensure
      s.close
      @stream = nil
    end

    private

    def prologue(stream)
      stream << %$
        #{Module::CAP}
        #ifndef #{@tag}
        #define #{@tag}
      $
    end

    def epilogue(stream)
      stream << %$
        #endif
      $
    end

    def stream = @stream ||= File.new(file_name, 'w')
  end


  class Module::Source

    include EntityContainer

    attr_reader :module

    attr_reader :complexity

    attr_reader :index

    def file_name = @file_name ||= self.module.source_count < 2 ? "#{self.module.name}_auto.c" : "#{self.module.name}_auto#{index}.c"

    def initialize(m, index)
      @module = m
      @complexity = 0
      @index = index
    end

    def render
      s = stream
      prologue(s)
      total_entities = ::Set.new
      entities.each { |e| total_entities.merge(e.total_dependencies) }
      ::SortedSet.new(total_entities).each { |e| e.declarations.each { |x| s << x } }
      ::SortedSet.new(entities).each { |e| e.implementation.each { |x| s << x } }
    ensure
      s.close
      @stream = nil
    end

    def <<(entity)
      @complexity += entity.complexity unless entities.include?(entity)
      super
    end

    private

    def prologue(stream)
      stream << %$
        #{Module::CAP}
        #include "#{self.module.header.file_name}"
      $
    end

    def stream = @stream ||= File.new(file_name, 'w')
  end


  module Entity

    def visibility = :public

    def dependencies = @dependencies ||= ::Set.new

    # Return the entire entity dependency set staring with self
    def total_dependencies = @total_dependencies ||= collect_dependencies(::Set.new)

    protected def collect_dependencies(set)
      unless set.include?(self)
        set << self
        dependencies.each { |d| d.collect_dependencies(set) }
      end
      set
    end

    def <=>(other) = dependencies.include?(other) ? +1 : -1 # Dependencies should precede self

    def interface
      @interface ||=
        begin
          stream = Module::Builder.new
          interface_declarations(stream)
          case visibility
          when :public
            interface_definitions(stream)
          end
          stream
        end
    end

    def declarations
      @declarations ||=
        begin
          stream = Module::Builder.new
          case visibility
          when :internal
            interface_definitions(stream)
          end
          forward_declarations(stream)
          stream
        end
    end

    def implementation
      @implementation ||=
        begin
          stream = Module::Builder.new
          definitions(stream)
          stream
        end
    end

    def complexity = declarations.complexity + implementation.complexity

    def interface_declarations(stream) = nil

    def interface_definitions(stream) = nil

    def forward_declarations(stream) = nil

    def definitions(stream) = nil

  end


  class Code

    include Entity

    def self.interface(s) = Code.new(interface: s)

    def initialize(interface: nil, declarations: nil, definitions: nil)
      @interface_ = interface
      @declarations_ = declarations
      @definitions_ = definitions
    end

    def interface_declarations(stream)
      super
      stream << @interface_ unless @interface_.nil?
    end

    def definitions(stream)
      super
      stream << @definitions_ unless @definitions_.nil?
    end

    def forward_declarations(stream)
      super
      stream << @declarations_ unless @declarations_.nil?
    end

  end


end