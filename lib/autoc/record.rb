# frozen_string_literal: true


require 'autoc/std'
require 'autoc/composite'


module AutoC


  using STD::Coercions


  # C struct wrapper with managed fields
  class Record < Composite

    attr_reader :fields

    def default_constructible? = fields.values.all? { |t| t.default_constructible? }
    def custom_constructible? = fields.values.all? { |t| t.copyable? }
    def destructible? = fields.values.any? { |t| t.destructible? }
    def comparable? = fields.values.all? { |t| t.comparable? }
    def copyable? = fields.values.all? { |t| t.copyable? }
    def hashable? = fields.values.all? { |t| t.hashable? }
    def orderable? = false
  
    def initialize(type, fields, visibility: :public, profile: :blackbox, **kws)
      super(type, visibility:, **kws)
      setup_profile(profile)
      setup_fields(fields)
    end

    def render_interface(stream)
      if public?
        stream << %{
          /**
            #{defgroup}

            @brief Value type wrapper of the C struct

            @since 2.0
          */
        }
        if @opaque
          stream << %{
            /**
              #{ingroup}

              @brief Opaque struct holding state of the record

              @since 2.0
            */
          }
        else
          stream << %{
            /**
              #{ingroup}

              @brief Open struct holding state of the record

              The struct's fields are directly acessible.
              However, care must be taken when modifying the struct's contents directly
              as it may break the contract(s) of certain (namely, hash- and tree-based) containers.

              For the safety reasons these fields should be generally treated read-only.

              @since 2.0
            */
          }
        end
      else
        stream << PRIVATE
      end
      stream << 'typedef struct {'
        fields.each { |name, type| stream << field_declaration(type, name) }
      stream << "} #{signature};"
    end

    def type_tag = "#{signature}<#{fields.values.join(',')}>"

  private

    # @private
    def setup_fields(fields)
      @fields = fields.transform_values { |type| type.to_type }
      self.fields.each_value { |type| dependencies << type }
    end

    # @private
    def setup_profile(profile)
      case profile
      when :blackbox
        #@inline_methods = false
        @omit_accessors = false
        @opaque = true
      when :glassbox
        #@inline_methods = true
        @omit_accessors = true
        @opaque = false
      else raise "unsupported profile #{profile}"
      end
    end

    # @private
    def field_variable(opt)
      if opt.is_a?(::Hash)
        obj, name = opt.first
        "#{obj}->#{name}"
      else
        opt
      end
    end

    # @private
    def field_declaration(type, name)
      s = "#{type} #{field_variable(name)};"
      s += @opaque ? '/**< @private */' : "/**< @brief Field of type #{type} */"
      s
    end

    def configure
      super
      ### set
        params = []
        docs = []
        args = { target: lvalue }
        fields.each do |name, type|
          formal = "_#{name}".to_sym
          value = type.const_rvalue
          params << [name, Parameter.new(value, formal)]
          args[formal] = value
          docs << "@param[in] #{formal} `#{name}` field initializer of type @ref #{type}"
        end
        method(:void, :set, args, instance: :custom_create).configure do
          _code = 'assert(target);'
          params.each do |field, parameter|
            _code += parameter.value.type.copy.("target->#{field}", parameter) + ';'
          end
          code _code
          header %{
            @brief Initialize record

            @param[in] target record to create
            #{docs.join("\n")}

            This function initializes new record's fields with copies of respective arguments.

            Previous contents of `*target` is overwritten.

            @since 2.0
          }
        end
      ### default_create
        _code = 'assert(target);'
        fields.each { |name, type| _code += type.default_create.("target->#{name}") + ';' }
        default_create.configure { code _code }
      ### destroy
        _code = 'assert(target);'
        fields.each { |name, type| _code += type.destroy.("target->#{name}") + ';' if type.destructible? }
        destroy.configure { code _code }
      ### copy
        _code = 'assert(target); assert(source);'
        fields.each { |name, type| _code += type.copy.("target->#{name}", "source->#{name}") + ';' }
        copy.configure { code _code }
      ### equal
        _code = 'assert(left); assert(right);'
        _code += 'return ' + fields.collect { |name, type| type.equal.("left->#{name}", "right->#{name}") }.join(' && ') + ';'
        equal.configure { code _code }
      ### hash_code
        _code = %{
          #{hasher.to_s} hash;
          size_t result;
          assert(target);
          #{hasher.create(:hash)};
        }
        fields.each { |name, type| _code += hasher.update(:hash, type.hash_code.("target->#{name}")) + ';' if type.hashable? }
        _code += %{
          result = #{hasher.result(:hash)};
          #{hasher.destroy(hash)};
          return result;
        }
        hash_code.configure { code _code }
        # TODO field accessors
  end

  end # Record


end