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

  def comparable? = fields.values.all?(&:comparable?)

  def copyable? = fields.values.all?(&:copyable?)

  ENDL = "\n"

  private def render_type_declaration(stream)
    comment = @profile == :glassbox && public? ? '/**< @public */' : '/**< @private */'
    stream << 'typedef struct {' << ENDL
      fields.each { |f, t| stream << "#{t} #{f}; #{comment}" + ENDL }
    stream << "} #{name_c};"
  end

  private def configure
    super
    default_create.code ENDL + fields.collect { |f, t| t.default_create.("target->#{f}").to_s + ';' + ENDL }.join
    destroy.code ENDL + fields.collect { |f, t| t.destructible? ? t.destroy.("target->#{f}").to_s + ';' + ENDL : nil }.compact.join
    equal.code ENDL + 'return ' + fields.collect { |f, t| t.equal.("lt->#{f}", "rt->#{f}").to_s }.join(' &&' + ENDL) + ';' + ENDL
    hash_code.code ENDL + 'return ' + fields.collect { |f, t| t.hash_code.("target->#{f}").to_s }.join(' ^' + ENDL) + ';' + ENDL # TODO employ custom hasher
    copy.code ENDL + fields.collect { |f, t| t.copy.("target->#{f}", "source->#{f}").to_s + ';' + ENDL }.join
  end
end


end
