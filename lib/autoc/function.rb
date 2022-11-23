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
  
  
  # Standalone C side function
  # The generated function is meant to be the C89-compliant
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
      @arguments = {}
      self.parameters.each { |parameter| @arguments[parameter.name] = parameter }
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
  
    def parameter(name) = @values[name]

    def call(*arguments)
      xs = []
      (0...arguments.size).each do |i|
        a = arguments[i]
        v = a.is_a?(Parameter) ? a.to_value_argument : a
        xs << (i < parameters.size ? parameters[i].value.(v) : v)
      end
      '%s(%s)' % [name, xs.join(',')]
    end
  
    def configure(&block) = instance_eval(&block)
    
    # This allows to call other functions with this function's individual parameters as arguments
    def method_missing(meth, *args) = @arguments.has_key?(meth) ? @arguments[meth] : super

  private

    # On function inlining in C: http://www.greenend.org.uk/rjk/tech/inline.html

    # static __inline seems to be THE way but consider the possible code bloat it incurs

    def render_declaration_specifier(stream)
      stream << 'static __inline ' if inline?
    end

    def render_function_header(stream)
      stream << %{
        /* #{@header} */
      } unless @header.nil?
    end

    def render_interface(stream)
      if live? && public?
        render_function_header(stream)
        render_declaration_specifier(stream)
        if inline?
          stream << definition
        else
          stream << prototype << ';'
        end
      end
    end

    def render_forward_declarations(stream)
      if live? && !public?
        if inline?
          stream << prototype << ';'
        else
          stream << definition
        end
      end
    end

    def render_implementation(stream)
      if live?
        stream << definition unless inline?
      end
    end

  end # Function


end