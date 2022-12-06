# frozen_string_literal: true


require 'autoc/std'
require 'autoc/type'
require 'autoc/module'
require 'autoc/function'


#require 'autoc/memory'
#require 'autoc/hasher'


module AutoC


  using STD::Coercions


  # @abstract
  class Composite < Type

    include STD

    include Entity

    attr_reader :visibility

    def initialize(signature, visibility: :public)
      super(signature)
      @methods = {}
      @visibility = visibility
    end

    def self.new(*args, **kws, &block)
      obj = super
      obj.send(:configure)
      obj
    end

    def to_value = rvalue

    def rvalue = @rv ||= Value.new(self, reference: true)
  
    def lvalue = @lv ||= Value.new(self, reference: true)
  
    def const_rvalue = @crv ||= Value.new(self, constant: true, reference: true)
  
    def const_lvalue = @clv ||= Value.new(self, constant: true, reference: true)

    # Prefix used to generate type-qualified identifiers
    # By default it returns the C side type signature but can be overridden
    # to handle the cases where the signature is not itself a valid C identifier (char*, for example)
    def prefix = signature

    def inspect = "#{signature} <#{self.class}>"

    # Decorate identifier with type-specific prefix
    def identifier(id)
      fn = id.to_s.sub(/[!?]$/, '') # Strip trailing !?
      # Check for leading underscore
      _ =
        if /^(_+)(.*)/ =~ fn
          fn = Regexp.last_match(2)
          true
        else
          false
        end
      # Convert _separated_names to the CamelCase
      id = prefix + fn.split('_').collect{ |s| s[0].upcase << s[1..-1] }.join
      # Carry over the method name's leading underscore only if the prefix is not in turn underscored
      _ && !prefix.start_with?('_') ? Regexp.last_match(1) + id : id
    end

    def respond_to_missing?(meth, include_private = false) = @methods.has_key?(meth) ? true : super

    def tag = signature

    def defgroup = @defgroup ||= (public? ? :@public : :@internal).to_s + " @defgroup #{signature} #{tag}"

    def ingroup = @ingroup ||= (public? ? :@public : :@internal).to_s + " @ingroup #{signature}"

  private
    
    def method_missing(meth, *args)
      if (method = @methods[meth]).nil?
        # On anything thats not a defined method return a type-decorated identifier
        # This allows to generate arbitrary type-qualified identifiers with #{type.foo}
        raise "unexpected arguments" unless args.empty?
        identifier(meth)
      else
        method
      end
    end

    # Overridable for custom method in derived classes
    def method_class = Method

    # Create a new type-bound function (aka method)
    def method(result, name, parameters, inline: false, visibility: nil, constraint: true, instance: name)
      method = method_class.new(
        self,
        result,
        name,
        parameters, # TODO force parameter types coercion
        inline:,
        visibility: (visibility.nil? ? self.visibility : visibility), # Method's visibility property can be borrowed from the type itself
        requirement: constraint
      )
      raise "##{instance} method redefinition is not allowed" if @methods.has_key?(instance)
      @methods[instance] = method
      references << method # Avoid introducing cyclic dependency due to the method's dependency on self
      method
    end

    def configure
      dependencies << DEFINITIONS
      method(:void, :create, { target: lvalue }, instance: :default_create, constraint: -> { default_constructible? }).configure do
        header %{
          @brief Create a new value

          @param[out] target value to be created

          This function constructs the value with parameterless constructor.

          Previous contents of `*target` is overwritten.

          Once constructed, the value is to be destroyed with @ref #{type.destroy}.

          @since 2.0
        }
      end
      method(:void, :destroy, { target: lvalue }, constraint: -> { destructible? }).configure do
        header %{
          @brief Destroy existing value

          @param[out] target value to be destroyed

          This function destroys the value previously constructed with any constructor.
          It involves freeing allocated memory and destroying the constituent values with the respective destructors.

          It is an error to use the value after call to this function (`*target` is considered to contain garbage afterwards).

          @since 2.0
        }
      end
      method(:void, :copy, { target: lvalue, source: const_rvalue }, constraint: -> { copyable? }).configure do
        header %{
          @brief Create a copy of source value

          @param[out] target value to be created
          @param[in]  source value to be cloned

          This function is meant to an independent copy (a clone) of `*source` value in place of `*target`.

          Previous contents of `*target` is overwritten.

          Once constructed, the value is to be destroyed with @ref #{type.destroy}.
          
          @since 2.0
        }
      end
      method(:int, :equal, { left: const_rvalue, right: const_rvalue }, constraint: -> { comparable? }).configure do
        header %{
          @brief Perform equality testing of two values

          @param[in] left  value to test for equality
          @param[in] right value to test for equality

          @return non-zero if values are considered equal and zero otherwise

          This function returns a non-zero value if specified values are considered equal and zero value otherwise.
          Normally the values' contents are considered on equality testing.

          @since 2.0
        }
      end
      method(:int, :compare, { left: const_rvalue, right: const_rvalue }, constraint: -> { orderable? }).configure do
        header %{
          @brief Compute relative ordering of two values

          @param[in] left  value to order
          @param[in] right value to order

          @return negative, positive or zero value depending on comparison of the specified values

          This function returns negative value if `left` precedes `right`, positive value if `left` follows `right` and zero if both values are considered equal.

          Normally the values' contents are considered on comparison.

          This function is in general independent to but is expected to be consistent with @ref #{type.equal} function.

          @since 2.0
        }
      end
      method(:size_t, :hash_code, { target: const_rvalue }, constraint: -> { hashable? } ).
        configure do
        header %{
          @brief Compute hash code

          @param[in] target value to compute hash code for

          @return hash code

          This function computes a hash code which reflects the value's contents in some way,
          that is two values considered equal must yield identical hash codes.
          Two different values may or may not yield identical hash codes, however.

          @since 2.0
        }
      end
    end

  end # Composite


  # Type-bound C side function
  class Composite::Method < Function

    attr_reader :type
  
    def initialize(type, result, name, parameters, **kws)
      @type = type
      super(result.to_value, self.type.identifier(name), parameters, **kws)
      dependencies << self.type << self.result.to_type
      # TODO register parameters' types as dependencies
    end

  private

    def render_function_header(stream)
      if public?
        stream << %{
          /**
            #{type.ingroup}
            #{@header}
          */
        }
      else
        stream << %{/** @private */}
      end
    end

    def render_declaration_specifier(stream)
      stream << (inline? ? 'AUTOC_INLINE ' : 'AUTOC_EXTERN ')
    end

  end # Method


  Composite::DEFINITIONS = Code.new interface: %{
    #ifndef AUTOC_INLINE
      #if defined(__cplusplus)
        #define AUTOC_INLINE extern "C" inline
      #else
        #if __STDC_VERSION__ >= 199901L
          #define AUTOC_INLINE inline
        #else
          #define AUTOC_INLINE static
        #endif
      #endif
    #endif
    #ifndef AUTOC_EXTERN
      #ifdef __cplusplus
        #define AUTOC_EXTERN extern "C"
      #else
        #define AUTOC_EXTERN extern
      #endif
    #endif
  }


end