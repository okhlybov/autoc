# frozen_string_literal: true


require 'autoc/composite'


module AutoC


  # C struct wrapper with managed fields
  class Structure < Composite

    attr_reader :fields

    def initialize(type, fields, visibility = :public)
      super(type, visibility)
      @fields = fields.transform_values { |type| Type.coerce(type) }
      self.fields.each_value { |type| dependencies << type }
      # Ordering is not supported by default
      trait_all_true(:default_constructible)
      trait_any_true(:destructible)
      trait_all_true(:comparable)
      trait_all_true(:hashable)
      trait_all_true(:copyable)
    end

    def default_constructible? = @default_constructible
    def custom_constructible? = copyable?
    def destructible? = @destructible
    def comparable? = @comparable
    def hashable? = @hashable
    def copyable? = @copyable
    def orderable? = false

    def composite_interface_declarations(stream)
      super
      stream << "
        /**
          #{defgroup}
          @brief
        */
        /**
          #{ingroup}
          @brief Opaque struct holding state of the structure
        */
        typedef struct {
      "
      fields.each { |name, type| stream << "#{type} _#{name}; /**< @private */\n" }
      stream << %"} #{type};"
    end

    private def configure
      super
      configure_accessors
      ### custom_create
      ctor_params = { self: type }
      fields.each { |name, type| ctor_params["_#{name}"] = type.const_type }
      def_method :void, :setup, ctor_params, instance: :custom_create, require:-> { copyable? } do
        _code = 'assert(self);'
        fields.each { |name, type| _code += type.copy("self->_#{name}", "_#{name}")+';' }
        code(_code)
      end
      ### default_create
      _code = 'assert(self);'
      fields.each { |name, type| _code += type.default_create("self->_#{name}")+';' }
      default_create.code _code
      ### destroy
      _code = 'assert(self);'
      fields.each { |name, type| _code += type.destroy("self->_#{name}")+';' if type.destructible? }
      destroy.code _code
      ### copy
      _code = 'assert(self); assert(source);'
      fields.each { |name, type| _code += type.copy("self->_#{name}", "source->_#{name}")+';' }
      copy.code _code
      ### equal
      _code = 'assert(self); assert(other);'
      _code += 'return ' + fields.to_a.collect { |name, type| type.equal("self->_#{name}", "other->_#{name}") }.join(' && ') + ';'
      equal.code _code
      ### hash_code
      _code = %{
        size_t hash;
        #{hasher.type} hasher;
        #{hasher.create(:hasher)};
      }
      fields.each { |name, type| _code += hasher.update(:hasher, type.hash_code("self->_#{name}"))+';' }
      _code += %{
        hash = #{hasher.result(:hasher)};
        #{hasher.destroy(:hasher)};
        return hash;
      }
      hash_code.code _code
    end

    private def configure_accessors
      fields.each do |name, field_type|
        if field_type.copyable?
          ### Getter
          meth = "get_#{name}".to_sym
          def_method field_type, meth, { self: const_type }
          send(meth).inline_code %{
            #{field_type} result;
            assert(self);
            #{field_type.copy(:result, "self->_#{name}")};
            return result;
          }
          ### Setter
          meth = "set_#{name}".to_sym
          def_method :void, meth, { self: type, "_#{name}": field_type.const_type }
          send(meth).inline_code %{
            assert(self);
            #{field_type.copy("self->_#{name}", "_#{name}")};
          }
        end
        ### Viewer
        meth = "view_#{name}".to_sym
        def_method field_type.const_ptr_type, meth, { self: const_type }
        send(meth).inline_code %{
          assert(self);
          return &self->_#{name};
        }
      end
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