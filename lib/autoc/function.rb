# frozen_string_literal: true


require 'autoc/core'
require 'autoc/module'


module AutoC
  

class Function
  
  include Entity

  alias core_initialize initialize

  def initialize(result, name, parameters = {}, spec: :extern, abstract: false, interface: :public, constraint: true, &code)
    core_initialize(result, name, parameters)
    @spec = spec
    @abstract = abstract
    @visibility = interface
    @constraint = constraint
    dependencies << Module::DEFINITIONS
    configure(&code) if block_given?
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

  DECLSPECS = {extern: :AUTOC_EXTERN, inline: :AUTOC_STATIC_INLINE}

  private def declspec_c = DECLSPECS[@spec]

  private def declaration_r
    header_r
    stream << "#{declspec_c}\n#{declaration_c}"
    inline? ? code_r : stream << ';'
  end

  private def definition_r
    if extern?
      stream << declaration_c
      code_r
    end
  end

  private def header_r
    stream << if public?
      %{
      /**
        #{@header}
      */
      }
    else
      '/** @private */'
    end
  end

  private def code_r
    @code.nil? ? raise("missing implementation code for function #{name_c}") : stream << '{' << @code << '}'
  end

end


end