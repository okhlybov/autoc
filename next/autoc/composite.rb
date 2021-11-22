# frozen_string_literal: true


require 'autoc/type'
require 'autoc/memory'
require 'autoc/hasher'


module AutoC


  # @abstract
  # Generator type for composite types which comprise of other primitive or composite types such as bare C structs
  # or elaborate data containers.
  class Composite < Type

    # Type-bound function with first refs parameters converted to references (mapped to C pointers).
    class Function < AutoC::Function

      #
      attr_reader :type

      def initialize(type, name, refs, parameters, result, inline = false)
        i = 0
        parameters =
          if parameters.is_a?(Array)
            parameters.collect { |t| (i += 1) <= refs ? ref_value_type(t) : t }
          else
            parameters.transform_values { |t| (i += 1) <= refs ? ref_value_type(t) : t }
          end
        super(Once.new { self.type.decorate_identifier(name) }, parameters, result)
        @inline = inline
        @type = type
        @refs = refs
      end

      def inline? = @inline

      # Account for definition of an inline function.
      def inline!(inline = true)
        @inline = inline
        self
      end

      def call(*args)
        if args.empty? then name # Emit bare function name
        elsif args.first.nil? then super() # Emit function call without parameters, fn()
        else
          i = 0
          super(args.collect { |v| (i += 1) <= @refs ? ref_value_call(v) : v }) # Emit function call with specified parameters, fn(...)
        end
      end

      private

      # Convert C value type to a pointer type
      def ref_value_type(type) = Once.new { "#{type}*" }

      def ref_value_call(arg) = Once.new { "&(#{arg})" }
    end

    # Prefix used to generate fully qualified type-specific identifiers.
    def prefix = @prefix ||= (@initial_prefix.nil? ? type : @initial_prefix).to_s

    #
    def declare(obj = nil)
      if obj.nil? then @declare
      elsif obj.inline? then "#{@define} #{obj.declaration}"
      else "#{@declare} #{obj.declaration}"
      end
    end

    #
    def define(obj = nil) = obj.nil? ? @define : "#{@define} #{obj.definition}"

    def memory = AutoC::Allocator.default

    def hasher = AutoC::Hasher.default

    attr_reader :visibility

    def initialize(type, visibility)
      super(type)
      # @custom_create
      @default_create = function(self, :create, 1, { self: type }, :void)
      @destroy = function(self, :destroy, 1, { self: type }, :void)
      @copy = function(self, :copy, 2, { self: type, source: const_type }, :void)
      @move = function(self, :move, 2, { self: type, source: type }, :void)
      @equal = function(self, :equal, 2, { self: const_type, other: const_type }, :int)
      @compare = function(self, :compare, 2, { self: const_type, other: const_type }, :int)
      @hash_code = function(self, :hash_code, 1, { self: const_type }, :size_t)
      @initial_prefix = nil
      @visibility = visibility
      dependencies.merge [CODE, memory, hasher]
    end

    private def function(*args) = Function.new(*args)

    def respond_to_missing?(*args) = SPECIAL_METHODS.include?(args.first) ? !instance_variable_get("@#{args.first}").nil? : super

    def method_missing(symbol, *args)
      if SPECIAL_METHODS.include?(symbol) && !(special = instance_variable_get("@#{symbol}")).nil?
        args.empty? ? special : special[*args]
      else
        function = decorate_identifier(symbol) # Construct C function name for the method
        if args.empty? then function # Emit bare function name
        elsif args.first.nil? then "#{function}()" # Use first nil argument to emit function call with no parameters
        else "#{function}(#{args.join(', ')})" # Emit normal function call with specified parameters
        end
      end
    end

    #
    def decorate_identifier(id)
      fn = id.to_s.sub(/[!?]$/, '') # Strip trailing !?
      # Check for leading underscore
      underscored =
        if /^(_+)(.*)/ =~ fn
          fn = Regexp.last_match(2)
          true
        else
          false
        end
      # Convert _separated_names to the CamelCase
      id = prefix + fn.split('_').collect(&:capitalize).join
      # Carry over the method name's leading underscore only if the prefix is not in turn underscored
      underscored && !prefix.start_with?('_') ? Regexp.last_match(1) + id : id
    end

    def interface_declarations(stream)
      super
      @declare = :AUTOC_EXTERN
      @define = :AUTOC_INLINE
      case visibility
      when :public
        @defgroup = '@public @defgroup'
        @addtogroup = '@public @addtogroup'
      else
        @defgroup = '@internal @defgroup'
        @addtogroup = '@internal @addtogroup'
      end
      composite_interface_declarations(stream)
    end

    def interface_definitions(stream)
      super
      @declare = :AUTOC_EXTERN
      @define = :AUTOC_INLINE
      case visibility
      when :public
        @defgroup = '@public @defgroup'
        @addtogroup = '@public @addtogroup'
      else
        @defgroup = '@internal @defgroup'
        @addtogroup = '@internal @addtogroup'
      end
      composite_interface_definitions(stream)
    end

    def composite_interface_declarations(stream) = nil

    def composite_interface_definitions(stream) = nil

    def forward_declarations(stream)
      super
      @declare = :AUTOC_EXTERN
      @define = :AUTOC_STATIC
      @defgroup = '@internal @defgroup'
      @addtogroup = '@internal @addtogroup'
    end

    def definitions(stream)
      super
      @declare = :AUTOC_STATIC
      @define = nil
      @defgroup = '@internal @defgroup'
      @addtogroup = '@internal @addtogroup'
    end

    CODE = Code.interface %$
      #include <stddef.h>
      #include <assert.h>
      #ifndef AUTOC_INLINE
        #if defined(_MSC_VER) || defined(__DMC__)
          #define AUTOC_INLINE AUTOC_STATIC __inline
        #elif defined(__LCC__)
          #define AUTOC_INLINE AUTOC_STATIC /* LCC rejects static __inline */
        #elif __STDC_VERSION__ >= 199901L || defined(__cplusplus)
          #define AUTOC_INLINE  AUTOC_STATIC inline
        #else
          #define AUTOC_INLINE AUTOC_STATIC
        #endif
      #endif
      #ifndef AUTOC_EXTERN
        #ifdef __cplusplus
          #define AUTOC_EXTERN extern "C"
        #else
          #define AUTOC_EXTERN extern
        #endif
      #endif
      #ifndef AUTOC_STATIC
        #if defined(_MSC_VER)
          #define AUTOC_STATIC __pragma(warning(suppress:4100)) static
        #elif defined(__GNUC__)
          #define AUTOC_STATIC __attribute__((__used__)) static
        #else
          #define AUTOC_STATIC static
        #endif
      #endif
      #define AUTOC_MIN(a,b) ((a) < (b) ? (a) : (b))
      #define AUTOC_MAX(a,b) ((a) > (b) ? (a) : (b))
    $

  end


end