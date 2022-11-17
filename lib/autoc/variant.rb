# frozen_string_literal: true


require 'autoc/composite'


module AutoC


  # C union wrapper with managed fields
  class Variant < Composite

    attr_reader :variants

    def default_constructible? = true

    def initialize(type, variants, visibility: :public, profile: :blackbox)
      super(type, visibility:)
      self.profile = profile
      self.variants = variants
    end

    # @private
    private def variants=(variants)
      @variants = variants.transform_values { |type| Type.coerce(type) }
      self.variants.each_value { |type| dependencies << type }
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
          @brief Synthesized managed discriminated union
        */
      }
      stream << %$
        /**
          #{ingroup}
          @brief Variants' tags
        */
      $
      stream << 'typedef enum {'
      i = -1; stream << (["#{void} = #{i+=1}"] + variants.collect { |name, type| "#{decorate_identifier(name)} = #{i+=1}" }).join(',')
      stream << "} #{tag};"
      if @opaque
        stream << %{
          /**
            #{ingroup}
            @brief Opaque struct holding state of the union
          */
        }
      else
        stream << %{
          /**
            #{ingroup}
            @brief Struct holding state of the union
          */
        }
      end
      stream << "typedef struct {#{tag} tag; /**< @private */ union {"
        variants.each { |name, type| stream << field_declaration(type, name) }
      stream << "} variant; /**< @private */ } #{type};"
    end

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
      ### default_create
        default_create.inline_code %{
          assert(self);
          self->tag = #{void};
        }
      ### destroy
        _code = %$
          assert(self);
          switch(self->tag) { case #{void}: break;
        $
        variants.each do |name, type|
          _code += "case #{decorate_identifier(name)}:"
          _code += type.destroy("self->variant.#{name}") if type.destructible?
          _code += ';break;'
        end
        _code += %{
          default:
            #ifndef NDEBUG
              abort();
            #endif
        }
        _code += '}'
        destroy.code _code
      ###
      copy.code %{

      }
      equal.code %{

      }
      compare.code %{

      }
      hash_code.code %{

      }
      ###
      variants.each do |name, type|
        def_method type.const_ptr_type, "view_#{name}", { self: self.const_type } do
          inline_code %{
            assert(self);
            assert(self->tag == #{decorate_identifier(name)});
            return &self->variant.#{name};
          }
        end
        def_method type, "get_#{name}", { self: self.const_type } do
          inline_code %{
            #{type} result;
            assert(self);
            assert(self->tag == #{decorate_identifier(name)});
            #{type.copy(:result, "self->variant.#{name}")};
            return result;
          }
        end if type.copyable?
        def_method :void, "set_#{name}", { self: self.type, value: type.const_type } do
          inline_code %{
            assert(self);
            #{destroy('*self') if destructible?};
            #{type.copy("self->variant.#{name}", :value)};
            self->tag = #{decorate_identifier(name)};
          }
        end if type.copyable?
      end
    end
end

end