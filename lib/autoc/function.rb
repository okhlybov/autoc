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

  def extern? = !static?

  def public? = @visibility == :public

  def private? = @visibility == :private

  def internal? = @visibility == :internal

  def abstract? = @abstract == true

  private def linkage_c = extern? ? :AUTOC_EXTERN : :static
  
  private def inline_c = inline? ? :AUTOC_INLINE : nil

end


end