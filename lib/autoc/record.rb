# frozen_string_literal: true


require 'autoc/composite'


module AutoC


using self


class Record < Composite

  attr_reader :fields

  def initialize(type, fields = {}, profile: :glassbox, **kws)
    super(type, **kws)
    @profile = profile
    @fields = fields.map { |name, type| [name.to_s, type.to_type] }.to_h
    self.dependencies.merge(self.fields.values)
    self.dependencies << ASSERT_H
  end

  def default_constructible? = fields.values.all?(&:default_constructible?)

  def destructible? = fields.values.any?(&:destructible?)

  def comparable? = fields.values.all?(&:comparable?)

  def copyable? = fields.values.all?(&:copyable?)

  def orderable? = false

  ENDL = "\n"

  private def render_type_declaration(stream)
    comment = @profile == :glassbox && public? ? '/**< @public */' : '/**< @private */'
    stream << 'typedef struct {' << ENDL
      fields.each { |field, type| stream << "#{type.name_c} #{field}; #{comment}" + ENDL }
    stream << "} #{name_c};"
  end

  private def configure
    super
    default_create.code ENDL + 'assert(target);' + fields.collect { |field, type| type.default_create.("target->#{field}").to_s + ';' + ENDL }.join
    destroy.code ENDL + 'assert(target);' + fields.collect { |field, type| type.destructible? ? type.destroy.("target->#{field}").to_s + ';' + ENDL : nil }.compact.join
    equal.code ENDL + 'assert(lt); assert(rt);' + 'return ' + fields.collect { |field, type| type.equal.("lt->#{field}", "rt->#{field}").to_s }.join(' &&' + ENDL) + ';' + ENDL
    hash_code.code ENDL + 'assert(target);' + 'return ' + fields.collect { |field, type| type.hash_code.("target->#{field}").to_s }.join(' ^' + ENDL) + ';' + ENDL # TODO employ custom hasher
    copy.code ENDL + 'assert(target); assert(source);' + fields.collect { |field, type| type.copy.("target->#{field}", "source->#{field}").to_s + ';' + ENDL }.join
  end
end


end
