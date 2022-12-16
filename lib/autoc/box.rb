# frozen_string_literal: true


require 'autoc/std'
require 'autoc/composite'


module AutoC


  using STD::Coercions


  # C union wrapper with managed fields
  class Box < Composite

    attr_reader :variants

    attr_reader :tag_

    def default_constructible? = true
    def custom_constructible? = false
    def destructible? = variants.values.any? { |t| t.destructible? }
    def comparable? = variants.values.all? { |t| t.comparable? }
    def orderable? = variants.values.all? { |t| t.orderable? }
    def copyable? = variants.values.all? { |t| t.copyable? }
    def hashable? = variants.values.all? { |t| t.hashable? }

    def initialize(type, variants, visibility: :public, profile: :blackbox)
      super(type, visibility:)
      setup_profile(profile)
      setup_variants(variants)
      @tag_ = "#{signature}_";
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
      stream << %{
        /**
          #{ingroup}

          @brief Box tag set

          Use @ref #{identifier(:tag)} to query current box contents. Empty box is always tagged as 0.

          @since 2.0
        */
      }
      stream << 'typedef enum {'
      i = 0; stream << (variants.collect { |name, type| "#{identifier(name)} = #{i+=1}" }).join(',')
      stream << "} #{tag_};"
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
      stream << "} variant; /**< @private */ #{tag_} tag; /**< @private */} #{signature};"
    end

  private

    # @private
    def setup_variants(variants)
      @variants = variants.transform_values { |type| type.to_type }
      self.variants.each_value { |type| dependencies << type }
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
      s += '/**< @private */' if @opaque
      s
    end

    def configure
      super
      default_create.configure do
        inline_code %{
          assert(target);
          target->tag = 0;
        }
      end
      method(tag_, :tag, { target: const_rvalue }).configure do
        inline_code %{
          assert(target);
          return target->tag;
        }
        header %{
          @brief Get type of contained element

          @param[in] target box to query
          @return tag of currently contained element

          This function returns a tag of currently contained element (@see @ref #{tag_}) or zero value if the box is empty (i.e. contains nothing).

          @since 2.0
        }
      end
      method(:void, :purge, { target: rvalue }).configure do
        code %{
          assert(target);
          #{destroy.(target) if destructible?};
          #{default_create.(target)};
        }
        header %{
          @brief Reset box

          @param[in] target box to purge

          This function resets the box by destroying containing element (if any).
          The box is left empty.

          @since 2.0
        }
      end
      ### destroy
        _code = %$
          assert(target);
          if(target->tag) switch(target->tag) {
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
          if(source->tag) switch(source->tag) {
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
          if(!left->tag) return 1;
          switch(left->tag) {
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
          if(!left->tag) return 0;
          switch(left->tag) {
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
          if(!target->tag) return AUTOC_HASHER_SEED;
          switch(target->tag) {
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

  end # Box


end