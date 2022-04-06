# frozen_string_literal: true


require 'autoc/type'
require 'autoc/memory'
require 'autoc/hasher'


module AutoC


  # @abstract
  # Generator type for composite types which comprise of other primitive or composite types such as bare C structs
  # or elaborate data containers.
  class Composite < Type

    #
    private def def_method(result, name, parameters, refs: 1, inline: false, visibility: nil, require: true, instance: name, &code)
      begin
        instance = instance.to_sym
        @_method = Method.new(self, name, parameters, result, refs, inline, visibility.nil? ? self.visibility : visibility, require)
        raise "Method definition for #{meth} is already registered" if @methods.key?(instance)
        @methods[instance] = @_method
        instance_eval(&code) if block_given?
      ensure
        @_method = nil
      end
    end

    #
    private def code(code) = @_method.code(code)
    
    #
    private def inline_code(code) = @_method.inline_code(code)

    #
    private def header(code) = @_method.header(code)

    #
    class Method < AutoC::Function

      attr_reader :type

      def initialize(type, name, parameters, result, refs, inline, visibility, guard)
        i = 0
        parameters =
          if parameters.is_a?(Array)
            parameters.collect { |t| (i += 1) <= refs ? ref_value_type(t) : t }
          else
            parameters.transform_values { |t| (i += 1) <= refs ? ref_value_type(t) : t }
          end
        # Use Once object to override default identifier decoration scheme
        super(name.is_a?(Once) ? name : Once.new { self.type.decorate_identifier(name) }, parameters, result)
        @type = type
        @refs = refs
        @guard = guard
        @inline = inline
        @visibility = visibility
      end

      def call(*args)
        if args.empty? then self # Return self to provide method chaining
        elsif args.first.nil? then super() # Emit function call without parameters, fn()
        else
          i = 0
          super(args.collect { |v| (i += 1) <= @refs ? ref_value_call(v) : v }) # Emit function call with specified parameters, fn(...)
        end
      end

      def code(code) = @code = code

      def inline_code(code)
        @inline = true
        @code = code
      end

      def header(info) = @info = info

      def method_missing(meth, *args) = type.send(meth, *args)

      attr_writer :inline

      def inline? = @inline == true

      def public? = @visibility == :public

      def live? = @live ||= (@guard.is_a?(Proc) ? @guard.() : @guard) == true

      attr_writer :visibility

      def interface_declaration(stream)
        if live?
          raise "Method body for #{self} is absent" if @code.nil?
          stream << if public?
            %{
              /**
                #{ingroup}
                #{@info}
              */
            }
          else
            %{
              /** @private */
            }
          end
          stream << "#{declare(self)};"
        end
      end

      def interface_definition(stream)
        stream << "#{define(self)} {#{@code}}" if live? && inline?
      end

      def implementation(stream)
        stream << "#{define(self)} {#{@code}}" if live? && !inline?
      end

      private

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

    # Perform additional configuration step following convetional initializition
    def self.new(*args, &code)
      obj = super
      obj.send(:configure)
      obj
    end

    def initialize(type, visibility)
      super(type)
      @methods = {}
      @initial_prefix = nil
      @visibility = visibility
      dependencies.merge [CODE, memory, hasher]
    end

    private def configure
      def_method :void, :create, { self: type }, instance: :default_create, require:-> { default_constructible? } do
        header %{
          @brief Create a new instance

          @param[out] self object to be created

          The instance is constructed with default constructor.

          @note Previous contents of `*self` is overwritten.

          @since 2.0
        }
      end
      def_method :void, :destroy, { self: type }, require:-> { destructible? } do
        header %{
          @brief Destroy the composite object along with all constituent parts

          @param[in] self object to be destructed

          Upon destruction all contained elements get destroyed in turn with respective destructors and allocated memory is reclaimed.
          After call to this function the `*self` storage can be disposed.

          @since 2.0
        }
      end
      def_method :void, :copy, { self: type, source: const_type }, refs: 2, require:-> { copyable? } do
        header %{
          @brief Create a new container with copies of the source container's elements

          @param[out] self container to be initialized
          @param[in] source container to obtain the elements from

          The container constructed with this function contains *copies* of all elements from `source`.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @note Previous contents of `*self` is overwritten.

          @since 2.0
        }
      end
      def_method :int, :equal, { self: const_type, other: const_type }, refs: 2, require:-> { comparable? } do
        header %{
          @brief Check whether two containers are equal by contents

          @param[in] self container to compare
          @param[in] other container to compare
          @return non-zero if the containers are equal by contents and zero otherwise

          The containers are considered equal if they contain the same number of the elements which in turn are pairwise equal.
          The exact semantics is container-specific, e.g. sequence containers like vector of list mandate the equal elements
          the elements are compared sequentially whereas unordered containers such as sets have no notion of the specific element position.

          This function requires the element type to be *comparable* (i.e. to have a well-defined comparison operation).

          @since 2.0
        }
      end
      def_method :int, :compare, { self: const_type, source: const_type }, refs: 2, require:-> { orderable? } do
        header %{
          @brief Compute the ordering of two containers

          @param[in] self container to order
          @param[in] other container to order
          @return zero if containers are considered equal, negative value if `self` < `other` and positive value if `self` > `other`

          The function computes the ordering of two containers based on respective contents.

          This function requires the element type to be *orderable* (i.e. to have a well-defined less-equal-more relation operation).

          @since 2.0
        }
      end
      def_method :size_t, :hash_code, { self: const_type }, require:-> { hashable? } do
        header %{
          @brief Return hash code for container

          @param[in] self container to get hash code for
          @return hash code

          The function computes a hash code - an integer value that somehow identifies the container's contents.

          This is done by employing the element's hash function, hence this function requires the container's
          element type to be *hashable* (i.e. to have a well-defined hash function).

          @since 2.0
        }
      end
    end

    def respond_to_missing?(*args) = @methods.key?(args.first.to_sym) ? true : super

    def method_missing(symbol, *args)
      if (meth = @methods[symbol]).nil?
        function = decorate_identifier(symbol) # Construct C function name for the method
        if args.empty? then function # Emit bare function name
        elsif args.first.nil? then "#{function}()" # Use first nil argument to emit function call with no parameters
        else "#{function}(#{args.join(', ')})" # Emit normal function call with specified parameters
        end
      else
        meth.(*args) # Delegate actual rendering to the function object
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

    private def defgroup = "#{@defgroup} #{type} #{canonic_tag}"
    private def ingroup = "#{@ingroup} #{type}"

    def interface_declarations(stream)
      super
      @declare = :AUTOC_EXTERN
      @define = :AUTOC_INLINE
      case visibility
      when :public
        @defgroup = '@public @defgroup'
        @ingroup = '@public @ingroup'
      else
        @defgroup = '@internal @defgroup'
        @ingroup = '@internal @ingroup'
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
        @ingroup = '@public @ingroup'
      else
        @defgroup = '@internal @defgroup'
        @ingroup = '@internal @ingroup'
      end
      composite_interface_definitions(stream)
    end

    def composite_interface_declarations(stream) = nil

    def composite_interface_definitions(stream)
      @methods.each_value { |meth| meth.interface_declaration(stream) }
      @methods.each_value { |meth| meth.interface_definition(stream) }
    end

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
      @methods.each_value { |meth| meth.implementation(stream) }
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

    # On function inlining in C: http://www.greenend.org.uk/rjk/tech/inline.html
  end


end