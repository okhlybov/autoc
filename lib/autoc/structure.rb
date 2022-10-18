# frozen_string_literal: true


require 'autoc/composite'


module AutoC


  # C struct wrapper with managed fields
  class Structure < Composite

    attr_reader :fields

    def initialize(type, fields, visibility: :public, profile: :blackbox)
      super(type, visibility:)
      self.profile = profile
      self.fields = fields
    end

    def default_constructible? = @default_constructible
    def custom_constructible? = copyable?
    def destructible? = @destructible
    def comparable? = @comparable
    def hashable? = @hashable
    def copyable? = @copyable
    def orderable? = false

    # @private
    private def fields=(fields)
      @fields = fields.transform_values { |type| Type.coerce(type) }
      self.fields.each_value { |type| dependencies << type }
      # trait_all_true(:orderable) # Ordering is not supported by default
      trait_all_true(:default_constructible)
      trait_any_true(:destructible)
      trait_all_true(:comparable)
      trait_all_true(:hashable)
      trait_all_true(:copyable)
    end

    # @private
    private def profile=(profile)
      case profile
      when :blackbox
        @inline_methods = false
        @omit_accessors = false
        @opaque = true
      when :glassbox
        @inline_methods = true
        @omit_accessors = true
        @opaque = false
      else raise "Unknown profile: #{profile}"
      end
    end

    def composite_interface_declarations(stream)
      super
      stream << %{
        /**
          #{defgroup}
          @brief Synthesized managed structure
        */
      }
      if @opaque
        stream << %{
          /**
            #{ingroup}
            @brief Opaque struct holding state of the structure
          */
        }
      else
        stream << %{
          /**
            #{ingroup}
            @brief Struct holding state of the structure
          */
        }
      end
      stream << 'typedef struct {'
        fields.each { |name, type| stream << field_declaration(type, name) << "\n" }
      stream << "} #{type};"
    end

    # @private
    private def defgroup = "#{@defgroup} #{type}"

    # @private
    private def field_variable(opt)
      if opt.is_a?(::Hash)
        obj, name = opt.first
        "#{obj}->#{name}"
      else
        opt
      end
    end

    # @private
    private def field_declaration(type, name)
      s = "#{type} #{field_variable(name)};"
      s += '/**< @private */' if @opaque
      s
    end

    private def configure
      super
      ### custom_create
        ctor_params = { self: type }
        fields.each { |name, type| ctor_params[field_variable(name)] = type.const_type }
        def_method :void, :setup, ctor_params, instance: :custom_create, require:-> { custom_constructible? } do
          _code = 'assert(self);'
          fields.each { |name, type| _code += type.copy(field_variable(self: name), field_variable(name))+';' }
          code(_code)
        end
      ### default_create
        _code = 'assert(self);'
        fields.each { |name, type| _code += type.default_create(field_variable(self: name))+';' }
        default_create.code _code
      ### destroy
        _code = 'assert(self);'
        fields.each { |name, type| _code += type.destroy(field_variable(self: name))+';' if type.destructible? }
        destroy.code _code
      ### copy
        _code = 'assert(self); assert(source);'
        fields.each { |name, type| _code += type.copy(field_variable(self: name), field_variable(source: name))+';' }
        copy.code _code
      ### equal
        _code = 'assert(self); assert(other);'
        _code += 'return ' + fields.to_a.collect { |name, type| type.equal(field_variable(self: name), field_variable(other: name)) }.join(' && ') + ';'
        equal.code _code
      ### hash_code
        _code = %{
          size_t hash;
          #{hasher.type} hasher;
          #{hasher.create(:hasher)};
        }
        fields.each { |name, type| _code += hasher.update(:hasher, type.hash_code(field_variable(self: name)))+';' }
        _code += %{
          hash = #{hasher.result(:hasher)};
          #{hasher.destroy(:hasher)};
          return hash;
        }
        hash_code.code _code
      ### accessors
        fields.each do |name, field_type|
          def_viewer(name, field_type)
          if field_type.copyable?
            def_getter(name, field_type)
            def_setter(name, field_type)
          end
        end
      # Mark all special methods as inline if requested
      [default_create, custom_create, destroy, copy, equal, compare, hash_code].each { |x| x.inline = true } if @inline_methods
    end

    # @private
    private def def_getter(name, field_type)
      meth = "get_#{name}".to_sym
      def_method field_type, meth, { self: const_type }, require:-> { !@omit_accessors }
      send(meth).inline_code %{
        #{field_type} result;
        assert(self);
        #{field_type.copy(:result, field_variable(self: name))};
        return result;
      }
    end

    # @private
    private def def_setter(name, field_type)
      meth = "set_#{name}".to_sym
      params = { self: type }
      params[field_variable(name)] = field_type.const_type
      def_method :void, meth, params, require:-> { !@omit_accessors }
      send(meth).inline_code %{
        assert(self);
        #{field_type.copy(field_variable(self: name), field_variable(name))};
      }
    end

    # @private
    private def def_viewer(name, field_type)
      meth = "view_#{name}".to_sym
      def_method field_type.const_ptr_type, meth, { self: const_type }, require:-> { !@omit_accessors }
      send(meth).inline_code %{
        assert(self);
        return &#{field_variable(self: name)};
      }
    end

    # @private
    # Set true if any of the fields' traits is true
    private def trait_any_true(trait)
      meth = "#{trait}?".to_sym
      x = fields.each_value { |type| break true if type.send(meth) == true }
      instance_variable_set("@#{trait}".to_sym, x == true)
    end

    # @private
    # Set true if all of the fields' traits are true
    private def trait_all_true(trait)
      meth = "#{trait}?".to_sym
      x = fields.each_value { |type| break false if type.send(meth) == false }
      instance_variable_set("@#{trait}".to_sym, x != false)
    end

  end
end