# frozen_string_literal: true


require 'autoc/type'
require 'autoc/module'
require 'autoc/primitive'


module AutoC


  using Refinements
    

  class Value

    attr_reader :type
  
    def to_type = type
  
    def to_value = self
  
    def constant? = @constant == true
  
    def reference? = @reference == true
  
    def initialize(type, constant: false, reference: false)
      @type = type
      @constant = constant
      @reference = reference
    end
  
    def signature
      _ = reference? ? "#{type.signature}*" : type.signature
      constant? ? "const #{_}" : _
    end
  
    def call(value) = reference? ? "&(#{value})" : value.to_s
  
  end # Value
  
  
  # Function parameter
  class Parameter
  
    attr_reader :value
  
    attr_reader :name
  
    def initialize(value, name)
      @value = value.to_value
      @name = name.to_sym
    end
  
    def to_value_argument = value.reference? ? "*#{name}" : name
  
    def signature = value.signature
  
    def declaration = '%s %s' % [signature, name]
  
  end # Parameter
  
  
  # Standalone function
  class Function
  
    include Entity
    
    attr_reader :name
  
    attr_reader :result
  
    attr_reader :parameters
  
    attr_reader :visibility

    def initialize(result, name, parameters, inline: false, visibility: :public, requirement: true)
      @result = result.to_type
      @name = name.to_s
      @requirement = requirement
      @visibility = visibility
      @inline = inline
      @parameters =
        if parameters.is_a?(Hash)
          parameters.collect { |name, descriptor| Parameter.new(descriptor, name) }
        else
          i = -1; parameters.collect { |descriptor| Parameter.new(descriptor, "_#{i+=1}") }
        end
    end
  
    def inline_code(code)
      @inline = true
      code(code)
    end
  
    def external_code(code)
      @inline = false
      code(code)
    end
  
    def header(header) = @header = header
  
    def code(code) = @code = code
  
    def to_s = name
  
    def inline? = @inline == true
  
    def public? = @visibility == :public
  
    def live? = (@requirement.is_a?(Proc) ? @requirement.() : @requirement) == true
    
    def defined? = !@code.nil?

    def signature = '%s(%s)' % [result.signature, parameters.collect(&:signature).join(',')]
  
    def prototype = '%s %s(%s)' % [result.signature, name, parameters.collect(&:declaration).join(',')]
  
    def definition = '%s {%s}' % [prototype, @code]
  
    def interface
      stream = super
      if live? && public?
        if inline?
          stream << definition
        else
          stream << prototype << ';'
        end
      end
      stream
    end

    def declaration
      stream = super
      if live? && !public?
        if inline?
          stream << prototype << ';'
        else
          stream << definition
        end
      end
      stream
    end

    def implementation
      stream = super
      if live?
        if !inline?
          stream << definition
        end
      end
      stream
    end

    def call(*arguments)
      if arguments.empty?
        name
      elsif arguments.first.nil?
        '%s()' % [name]
      else
        xs = []
        (0...arguments.size).each do |i|
          a = arguments[i]
          v = a.is_a?(Parameter) ? a.to_value_argument : a
          xs << (i < parameters.size ? parameters[i].value.(v) : v)
        end
        '%s(%s)' % [name, xs.join(',')]
      end
    end
  
    def configure(&block) = instance_eval(&block)
  
  end # Function


end