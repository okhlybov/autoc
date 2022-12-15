# frozen_string_literal: true


require 'autoc/std'
require 'autoc/composite'


module AutoC


  using STD::Coercions


  # C union wrapper with managed fields
  class Variant < Composite

    attr_reader :variants

    def default_constructible? = true

    def initialize(type, variants, visibility: :public, profile: :blackbox)
      super(type, visibility:)
      setup_profile(profile)
      setup_variants(variants)
      @default = %{
        #ifndef NDEBUG
          abort();
        #endif
      }
    end

    def render_interface(stream)
      stream << %{
        /**
          #{defgroup}
          @brief Value type wrapper of the C union
        */
      }
      stream << 'typedef enum {'
      i = -1; stream << (["#{identifier(:void)} = #{i+=1}"] + variants.collect { |name, type| "#{identifier(name)} = #{i+=1}" }).join(',')
      stream << "} #{identifier(:_tag)}; /**< @private */"
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
      stream << "typedef struct {union {"
        variants.each { |name, type| stream << field_declaration(type, name) }
      stream << "} variant; /**< @private */ #{identifier(:_tag)} tag; /**< @private */} #{signature};"
    end

  private

    # @private
    def setup_variants(variants)
      @variants = variants.transform_values { |type| type.to_type }
      self.variants.each_value { |type| dependencies << type }
      #trait_any_true(:destructible)
      #trait_all_true(:comparable)
      #trait_all_true(:hashable)
      #trait_all_true(:copyable)
    end

    # @private
    def setup_profile(profile)
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
      s += '/**< @private */' if @opaque
      s
    end

    def configure
      super
      default_create.configure do
        inline_code %{
          assert(target);
          target->tag = #{identifier(:void)};
        }
      end
      ### destroy
        _code = %$
          assert(target);
          switch(target->tag) { case #{identifier(:void)}: break;
        $
        variants.each do |name, type|
          _code += "case #{identifier(name)}:"
          _code += type.destroy.("target->variant.#{name}") if type.destructible?
          _code += ';break;'
        end
        _code += %{
          default: #{@default}
        }
        _code += '}'
        destroy.configure { code _code }
      ### copy
        _code = %$
          assert(target);
          assert(source);
          switch(target->tag) { case #{identifier(:void)}: break;
        $
        variants.each do |name, type|
          _code += "case #{identifier(name)}:"
          _code += type.copy.("target->variant.#{name}", "source->variant.#{name}")
          _code += ';break;'
        end
        _code += %{
          default: #{@default}
        }
        _code += '} target->tag = source->tag;'
        copy.configure { code _code }
      ### equal
        _code = %$
          assert(left);
          assert(right);
          if(left->tag != right->tag) return 0;
          switch(left->tag) { case #{identifier(:void)}: return 1; break;
        $
        variants.each do |name, type|
          _code += "case #{identifier(name)}:"
          _code += 'return '
          _code += type.equal.("left->variant.#{name}", "right->variant.#{name}")
          _code += ';'
        end
        _code += %{
          default: #{@default}
        }
        _code += '}'
        equal.configure { code _code }
      ### compare
        _code = %$
          assert(left);
          assert(right);
          assert(left->tag == right->tag);
          switch(left->tag) { case #{identifier(:void)}: return 0; break;
        $
        variants.each do |name, type|
          _code += "case #{identifier(name)}: return "
          _code += type.compare.("left->variant.#{name}", "right->variant.#{name}")
          _code += ';'
        end
        _code += %{
          default: #{@default}
        }
        _code += '}'
        compare.configure { code _code }
      ### hash_code
        _code = %$
          assert(target);
          switch(target->tag) { case #{identifier(:void)}: return AUTOC_HASHER_SEED; break;
        $
        variants.each do |name, type|
          _code += "case #{identifier(name)}: return "
          _code += type.hash_code.("target->variant.#{name}")
          _code += ';'
        end
        _code += %{
          default: #{@default}
        }
        _code += '}'
        hash_code.configure { code _code }
      ### typed accessors
      _type = self
      variants.each do |name, type|
        method(type.const_lvalue, "view_#{name}", { target: const_rvalue }).configure do
          inline_code %{
            assert(target);
            assert(target->tag == #{identifier(name)});
            return &target->variant.#{name};
          }
        end
        if type.copyable?
          method(type, "get_#{name}", { target: const_rvalue }).configure do
            inline_code %{
              #{type} result;
              assert(target);
              assert(target->tag == #{identifier(name)});
              #{type.copy.(:result, "target->variant.#{name}")};
              return result;
            }
          end
          method(:void, "set_#{name}", { target: rvalue, value: type.const_rvalue }).configure do
            inline_code %{
              assert(target);
              #{destroy.(target) if destructible?};
              #{type.copy.("target->variant.#{name}", value)};
              target->tag = #{identifier(name)};
            }
          end
        end
      end
    end
end

end