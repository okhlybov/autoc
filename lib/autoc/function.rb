# frozen_string_literal: true


require 'autoc/type'
require 'autoc/module'
require 'autoc/primitive'


module AutoC


  # :nodoc:
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
  
    def to_s = signature

    def signature
      _ = reference? ? "#{type.signature}*" : type.signature
      constant? ? "const #{_}" : _
    end
  
    def call(value) = reference? ? "&(#{value})" : value.to_s
  
  end # Value
  
  
  # :nodoc:
  # Function parameter
  class Parameter
  
    attr_reader :value
  
    attr_reader :name
  
    def initialize(value, name)
      @value = value.to_value
      @name = name.to_sym
    end
  
    def to_s = name.to_s

    def to_value_argument = value.reference? ? "*#{name}" : name
  
    def signature = value.signature
  
    def declaration = '%s %s' % [signature, name]
  
  end # Parameter
  
  
  # Standalone C side function
  # The generated function is meant to be the C89-compliant
  # NOTE: This function does not track parameter and result types as its dependencies
  # This can be done manually by appending to #dependencies property with <<
  class Function
  
    include Entity
    
    attr_reader :name
  
    attr_reader :result
  
    attr_reader :parameters
  
    attr_reader :visibility

    attr_writer :inline

    def initialize(result, name, parameters, inline: false, visibility: :public, requirement: true, abstract: false)
      @name = name.to_s
      @result = result
      @inline = inline
      @visibility = visibility
      @requirement = requirement
      @abstract = abstract
      @parameters = Parameters.new(self)
      if parameters.is_a?(Hash)
        parameters.each do |name, descriptor|
          x = Parameter.new(descriptor, name)
          @parameters[x.name] = x
        end
      else
        i = -1
        parameters.each do |descriptor|
          x = Parameter.new(descriptor, "_#{i+=1}")
          @parameters[x.name] = x
        end
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
  
    def to_s = name

    def header(header) = @header = header
  
    def code(code) = @code = code
  
    def inspect = "#{prototype} <#{self.class}>"
  
    def inline? = @inline == true
  
    def public? = @visibility == :public

    def abstract? = @abstract == true
  
    def live? = (@requirement.is_a?(Proc) ? @requirement.() : @requirement) == true
    
    def signature = '%s(%s)' % [result.signature, parameters.to_a.collect(&:signature).join(',')]
  
    def prototype = '%s %s(%s)' % [result.signature, name, parameters.to_a.collect(&:declaration).join(',')]
  
    def definition = '%s {%s}' % [prototype, @code]
  
    def parameter(name) = @values[name]

    def call(*arguments)
      xs = []
      ps = parameters.to_a
      (0...arguments.size).each do |i|
        a = arguments[i]
        v = a.is_a?(Parameter) ? a.to_value_argument : a
        xs << (i < ps.size ? ps[i].value.(v) : v)
      end
      '%s(%s)' % [name, xs.join(',')]
    end
  
    def configure(&block)
      instance_eval(&block)
      self
    end
    
    # This allows to call other functions with this function's individual parameters as arguments
    # A call to unknown method results in the method's name being emitted
    def method_missing(meth, *args) = parameters.has_key?(meth) ? parameters[meth] : meth

  private

    # On function inlining in C: http://www.greenend.org.uk/rjk/tech/inline.html

    # static inline seems to be THE most portable way without resorting to preprocessor
    # but consider the possible code bloat it incurs

    def render_declaration_specifier(stream)
      # The inline specifier is not a part of C89 yet descent compilers do inlining at will
      # given the function definition is available at the function call
      stream << 'static ' if inline?
    end

    # Render the commentary block preceding the function declaration, both inline or external
    def render_function_header(stream)
      stream << %{
        /* #{@header} */
      } unless @header.nil?
    end

    # Render full function declaration statement including the commentary block
    # For inline functions this also renders a function body effectively making this also a function definition
    # The declaration comes into either public interface of forward declaration block depending on the function's visibility status
    def render_function_declaration(stream)
      render_function_header(stream)
      render_declaration_specifier(stream)
      if inline?
        render_function_definition(stream)
      else
        stream << prototype << ';'
      end
    end

    # Render function definition, both inline or extern
    # This code never gets into public interface
    def render_function_definition(stream)
      unless abstract?
        raise("missing function definition for #{name}()") if @code.nil?
        stream << definition
      end
    end

    # Render function's public interface
    # Only public functions are rendered
    def render_interface(stream)
      render_function_declaration(stream) if live? && public?
    end

    # Render function's interface for non-public functions which should not appear in the public interface
    def render_forward_declarations(stream)
      render_function_declaration(stream) if live? && !public?
    end

    # Render non-inline function definition regardless of function's visibility status
    def render_implementation(stream)
      if live?
        if inline?
          stream << "extern #{prototype};" # Force generation of the C99 externally-visible definition of inline function
        else
          render_function_definition(stream)
        end
      end
    end

  end # Function


  # :nodoc:
  # Named parameter list for the function
  class Function::Parameters < ::Hash
    def initialize(function)
      @function = function
      super()
    end
    def to_a = values
    def [](name)
      raise "unknown parameter #{name} in function #{@function}()" unless has_key?(name)
      super
    end
  end # Parameters


end