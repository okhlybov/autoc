# frozen_string_literal: true


require 'autoc/core'
require 'autoc/module'
require 'autoc/callable'


module AutoC


class Function < Callable

  include Entity

  # C side function name
  attr_reader :name_c

  def initialize(result, name, parameters = {}, spec: :extern, abstract: false, visibility: :public, constraint: true, &code)
    super(result, parameters)
    @name_c = name.to_s
    @spec = spec
    @abstract = abstract
    @visibility = visibility
    @constraint = constraint
    dependencies << DEFINITIONS
    self.parameters.values.each { |x| dependencies << x.type }
    dependencies << self.return.type unless self.return.nil?
    configure(&code) if block_given?
  end

  def to_s = '%s(%s)' % [name_c, parameters_c]

  def declaration_c = '%s %s(%s)' % [return_c, name_c, parameters_c]

  def inspect = "#{declaration_c} <#{self.class}>"

  def call(*arguments) = Call.new(self, arguments)

  class Call < Callable::Call
    def to_s = '%s(%s)' % [callable.name_c, arguments_c]
  end

  def live? = (@constraint.is_a?(Proc) ? @constraint.() : @constraint) == true

  def public? = @visibility == :public

  def private? = @visibility == :private

  def internal? = @visibility == :internal

  def abstract? = @abstract == true

  def extern? = @spec == :extern

  def inline? = @spec == :inline

  # C(++) inline notes:
  # https://stackoverflow.com/questions/216510/what-does-extern-inline-do/216546#216546

  def render_interface(stream)
    if live?
      @stream = stream
      declaration_r unless internal?
    end
  end

  def render_forward_declarations(stream)
    if live?
      @stream = stream
      declaration_r if internal?
    end
  end

  def render_implementation(stream)
    if live?
      @stream = stream
      definition_r
    end
  end

  def header(x) = @header = x

  def code(x) = @code = x

  def inline_code(x)
    @spec = :inline
    code(x)
  end

  def configure(&code)
    instance_eval(&code)
    self
  end

  private attr_reader :stream

  DECLSPECS = { extern: :AUTOC_EXTERN, inline: :AUTOC_STATIC_INLINE }

  private def declspec_c = DECLSPECS[@spec]

  private def declaration_r
    header_r
    stream << "#{declspec_c}\n#{declaration_c}"
    inline? && !abstract? ? code_r : stream << ';'
  end

  private def definition_r
    if extern? && !abstract?
      stream << declaration_c
      code_r
    end
  end

  private def header_r
    if public?
      unless @header.nil?
        stream << %{
          /**
            #{@header}
          */
        }
      end
    else
      stream << '/** @private */'
    end
  end

  private def code_r
    @code.nil? ? raise("missing implementation code for function #{name_c}") : stream << '{' << @code << '}'
  end

  DEFINITIONS = Code.new interface: %{
    #ifndef AUTOC_EXTERN
      #ifdef __cplusplus
        #define AUTOC_EXTERN extern "C"
      #else
        #define AUTOC_EXTERN extern
      #endif
    #endif
    #ifndef AUTOC_STATIC_INLINE
      #if defined(__cplusplus) || (defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L)
        #define AUTOC_STATIC_INLINE static inline
      #else
        #define AUTOC_STATIC_INLINE static
      #endif
    #endif
  }

end


end
