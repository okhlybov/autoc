# frozen_string_literal: true


require 'autoc/core'
require 'autoc/module'


module AutoC
  

class Function
  
  include Entity

  alias core_initialize initialize

  def initialize(result, name, parameters = {}, inline: false, static: false, abstract: false, visibility: :public, constraint: true)
    core_initialize(result, name, parameters)
    @inline = inline
    @static = static
    @abstract = abstract
    @visibility = visibility
    @constraint = constraint
    definitions.each { |x| dependencies << x } # TODO inject parameters' types
  end

  # Overridable set of entities to be injected into dependency set
  private def definitions = [Module::DEFINITIONS]

  def live? = (@constraint.is_a?(Proc) ? @constraint.() : @constraint) == true

  def inline? = @inline == true

  def static? = @static == true

  def extern? = !inline? && !static?

  def public? = @visibility == :public

  def private? = @visibility == :private

  def internal? = @visibility == :internal

  def abstract? = @abstract == true

  def render_interface(stream)
    @stream = stream
    declaration_r unless internal?
  end

  def render_forward_declarations(stream)
    @stream = stream
    declaration_r if internal?
    # A non-inline static function still separates declaration and definiton
    # but the definition should be present in every translation unit
    # that references this function threrefore it is put into
    # forward declaration section, not the implementation one
    if static? && !inline?
      stream << "#{linkage_c} #{declaration_c}" # static is mandatory here to match the static declaration
      code_r
    end
  end

  private def declaration_r
    stream << header_c
    # Inline declaration always comes with definition regardless of the linkage specifiers
    if inline?
      stream << "#{static? ? :static : nil} AUTOC_INLINE #{declaration_c}"
      code_r
    else
      # Non-inline function declaration coming into either public interface header or
      # forward declarations sections of the translation units
      if extern? || static?
        stream << "#{linkage_c} #{declaration_c};"
      end
    end
  end

  def render_implementation(stream)
    @stream = stream
    # Regular extern C(++) function definition
    if extern?
      # No function decorators are put here as they should've been
      # provided by the function definition code
      stream << declaration_c
      code_r
    end
    # Non-static inline function definition in a single translation unit
    # This is required by the C mode only as C++ has different inline semantics
    # A static inline definition is provided during declaration,
    # in the same way as for the regular inline
    if inline? && !static?
      no_cxx_r("AUTOC_EXTERN #{declaration_c};")
    end
  end

  # Function render implementation

  private attr_reader :stream

  private def linkage_c
    return :static if static?
    return :AUTOC_EXTERN if extern?
    nil
  end

  private def inline_c = inline? ? :AUTOC_INLINE : nil

  private def header_c
    # TODO
    if public?
      %{/* @public */}
    else
      %{/* @private */}
    end
  end

  private def no_cxx_r(code)
    stream << %{
      #ifndef __cplusplus
        #{code}
      #endif
    }
  end

  private def code_r
    stream << '{}' # TODO
  end
end


end