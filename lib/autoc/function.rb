# frozen_string_literal: true


require 'autoc/module'
require 'autoc/callable'


module AutoC


using self


class Function < Callable

  include Entity

  attr_reader :name_c

  def initialize(result, name, parameters = {}, type: :external, visibility: :public, abstract: false, constraint: true, dependencies: [], &code)
    super(result, parameters)
    @name_c = name.to_s
    @type = type
    @visibility = visibility
    @abstract = abstract
    @constraint = constraint
    self.dependencies.merge([@@definitions, self.result].compact + self.parameters.values.collect(&:type) + Array(dependencies))
    configure(&code) if block_given?
  end

  def arguments = parameters.values # Used to pass the function's local parameters to another function (possibly itself) as arguments

  def call(*arguments) = Call.new(self, arguments)

  class Call < Callable::Call

    def to_s = '%s(%s)' % [callable.name_c, callable.parameters.values.zip(arguments).map { |p, v| v.bind_c(p) }.join(', ')]

  end

  def declaration_c = '%s %s(%s)' % [result.nil? ? :void : result.name_c, name_c, parameters.values.map { |v| v.declaration_c }.join(', ')]

  def live? = (@constraint.is_a?(Proc) ? @constraint.() : @constraint) == true

  def public? = @visibility == :public

  def private? = @visibility == :private

  def internal? = @visibility == :internal

  def abstract? = @abstract == true

  def external? = @type == :external

  def inline? = @type == :inline

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
    @type = :inline
    code(x)
  end

  def configure(&code)
    instance_eval(&code)
    self
  end

  @@types = { external: :AUTOC_EXTERN, inline: :AUTOC_STATIC_INLINE }

  private attr_reader :stream

  private def declaration_r
    header_r
    stream << "#{@@types[@type]}\n#{declaration_c}"
    inline? && !abstract? ? code_r : stream << ';'
  end

  private def definition_r
    if external? && !abstract?
      stream << declaration_c
      code_r
    end
  end

  private def header_r
    if public?
      if @header.nil?
        stream << '/** @public */'
      else
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

  @@definitions = Code.new interface: %{
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
