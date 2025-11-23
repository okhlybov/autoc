# frozen_string_literal: true


require 'autoc/composite'


module AutoC


using Coercions


class Record < Composite

  attr_reader :fields

  def initialize(type, fields = {}, profile: :glassbox, **kws)
    super(type, **kws)
    @fields = fields.map { |n, t| [n.to_s, t.to_type] }.to_h
    @profile = profile
    self.fields.values.each { |t| dependencies << t }
  end

  def default_constructible? = fields.values.all?(&:default_constructible?)

  def destructible? = fields.values.any?(&:destructible?)

  private def render_type_declaration(stream)
    comment = @profile == :glassbox && public? ? '/**< @public */' : '/**< @private */'
    stream << 'typedef struct {'
      fields.each { |f, t| stream << "#{t} #{f}; #{comment}" }
    stream << "} #{name_c};"
  end

end


end
