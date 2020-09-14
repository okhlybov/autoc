require 'set'
require 'autoc/module'


module AutoC


  #
  class TraitError < TypeError; end # TraitError


  # A base for the source side types.
  module Type

    #
    def self.coerce(obj)
      obj.is_a?(Type) ? obj : Primitive.new(obj)
    end

    # Return source side type string identifier.
    # @return [String] source side type identifier
    attr_reader :type

    def initialize(type)
      @type = type.to_s
    end

    # @!group Rule-Of-Five concepts controlling the type's instance lifetime

    # @abstract
    # Synthesize the source side code to create an instance in place of the +value+ and perform its default initialization (the default constructor).
    #
    # Original contents of the +value+ is overwritten.
    #
    # @param value [String | Symbol] source side storage designation where the instance is to be created
    # @return [String] source side code snippet
    def default_create(value) end; remove_method :default_create

    # @abstract
    # Synthesize the source side code to create an instance in place of the +value+ and and initialize it with supplied +args+ (the custom constructor).
    #
    # The +args+ elements are expected to be of the {Type} type.
    #
    # Original contents of the +value+ is overwritten.
    #
    # @param value [String | Symbol] source side storage designation where the instance is to be created
    # @param args [Array] list of types to be supplied to the constructor
    # @return [String] source side code snippet
    def custom_create(value, *args) end; remove_method :custom_create

    # Array of types to be supplied to custom constructor {#custom_create}.
    #
    # @note Array elements are assumed to be of the {Type} type.
    attr_reader :custom_create_params

    # Set the custom constructor parameters.
    # @note Performs the type coercion procedure on supplied arguments.
    private def custom_create_params=(ary)
      @custom_create_params = Params.new(ary)
    end

    # @abstract
    # Synthesize the source side code to create an instance in place of the +value+ initializing it with a contents of the +origin+ instance (the copy constructor).
    #
    # Original contents of the +value+ is overwritten.
    # The contents of the +origin+ is left intact.
    #
    # @param value [String | Symbol] source side storage designation where the instance is to be created
    # @param origin [String | Symbol] source side storage designation taken as the origin for the cloning operation
    # @return [String] source side code snippet
    def clone(value, origin) end; remove_method :clone

    # @abstract
    # Synthesize the source side code to transfer the contents of +origin+ into the +value+ (the move constructor).
    # This code may either create a instance in place of +value+ or move the data from +origin+ to +value+, depending on the implementation.
    #
    # Original contents of the +value+ is overwritten.
    # The contents of the +origin+ is no longer valid afterwards.
    #
    # @param value [String | Symbol] source side storage designation where the instance is to be placed
    # @param origin [String | Symbol] source side storage designation taken as the origin for the transfer operation
    # @return [String] source side code snippet
    def move(value, origin) end; remove_method :move

    # @abstract
    # @note Optional operation.
    # Synthesize the source side code to destroy the instance in place of the +value+ (the destructor).
    #
    # @param value [String | Symbol] source side storage designation for the instance to be destroyed
    # @return [String] source side code snippet
    def destroy(value) end; remove_method :destroy

    # Test whether the type has a default (parameterless) constructor.
    #
    # This implementation looks up the {#default_create} method.
    def default_constructible?
      respond_to?(:default_create)
    end

    # Test whether the type has a custom constructor which accepts a number of parameters.
    #
    # This implementation looks up the {#custom_create} method.
    def custom_constructible?
      respond_to?(:custom_create)
    end

    # Test whether the type can be constructed, with either default or parametrized initialization.
    #
    # This implementation queries {#custom_constructible?} and {#default_constructible?}.
    def constructible?
      custom_constructible? || default_constructible?
    end

    # Test whether the type can be created from an instance of the same type (cloned).
    #
    # This implementation looks up the {#clone} method.
    def cloneable?
      respond_to?(:clone)
    end

    # Test whether the type's instance can be transferred from one location to another.
    #
    # This implementation looks up the {#move} method.
    def movable?
      respond_to?(:move)
    end

    # Test whether the type has a non-trivial destructor.
    #
    # This implementation looks up the {#destroy} method.
    def destructible?
      respond_to?(:destroy)
    end

    #@!group Comparison traits

    #
    def equal(value, other) end; remove_method :equal

    #
    def less(value, other) end; remove_method :less

    #
    def equality_testable?
      respond_to?(:equal)
    end

    #
    def comparable?
      equality_testable? && respond_to?(:less)
    end

    #@!group Hashing traits

    #
    def identify(value) end; remove_method :identify

    #
    def hashable?
      respond_to?(:equal) && respond_to?(:identify)
    end

    #@!endgroup

    # @private
    class Params < Array
      def initialize(ary)
        super(ary.collect {|t| AutoC::Type.coerce(t)})
      end
      def declare_list
        i = 0; collect {|t| "#{t.type} __#{i+=1}__"}
      end
      def declare
        declare_list.join(',')
      end
      def pass_list
        (1..size).collect {|i| "__#{i}__"}
      end
      def pass
        pass_list.join(',')
      end
    end # Params

  end # Type


  #
  class Primitive

    include Type
    include Module::Entity

    def initialize(*args)
      super
      self.custom_create_params = [self]
    end

    def default_create(value)
      custom_create(value, 0)
    end

    def custom_create(value, init)
      "(#{value} = #{init})"
    end

    def clone(value, origin)
      "(#{value} = #{origin})"
    end

    def equal(value, other)
      "(#{value} == #{other})"
    end

    def less(value, other)
      "(#{value} < #{other})"
    end

    def identify(value)
      "((size_t)#{value})"
    end

  end # Primitive


  # @private
  module MethodSynthesizer
    def method_missing(symbol, *args)
      function = decorate_method(symbol) # Construct C function name for the method
      if args.empty?
        function # Emit bare function name
      elsif args.size == 1 && args.first.nil?
        function + '()' # Use sole nil argument to emit function call with no arguments
      else
        function + '(' + args.join(',') + ')' # Emit normal function call with supplied arguments
      end
    end
    # @abstract
    def decorate_method(symbol) end; remove_method :decorate_method
  end # MethodSynthesizer


  # @private
  module DependencyComposer
    attr_reader :dependencies
    private def dependencies=(ary)
      @dependencies = Set[*ary]
    end
  end # DependencyComposer


  # @private
  module Redirector
    def redirect(meth, redirect_args = 0)
      class_eval %~
        def #{meth}(*args)
          method_missing(:#{meth}, *Redirector.redirect(args, #{redirect_args}))
        end
      ~
    end
    def self.redirect(args, redirect_args = 0)
      if args.size == 1 && args.first.nil?
        [nil]
      else
        n = [redirect_args, args.size].min
        ls = (n.zero? ? args : args[0..n-1]).collect {|x| "&#{x}"}
        rs = n.zero? ? [] : args[n..-1]
        ls + rs
      end
    end
  end


  # @private
  module ConstructibleAdapter

    def initialize(*args, **kws)
      super(*args, **kws)
      if default_constructible?
        @default_create = :create
        @custom_create = :createEx
      else
        @custom_create = :create
      end
    end

    def default_create(value)
      send(@default_create, *Redirector.redirect([value], 1))
    end

    def custom_create(value, *args)
      send(@custom_create, *Redirector.redirect([value] + args, 1))
    end

  end # CreateForwarder


  # @private
  module Hashable

    extend Redirector

    redirect :identify, 1

    def hasher
      AutoC::Hasher.default
    end

    def initialize(*args, **kws)
      super(*args, **kws)
      dependencies << hasher
    end

    def interface(stream)
      super
      interface_identify(stream)
    end

    def definition(stream)
      super
      define_identify(stream)
    end

    def interface_identify(stream)
      stream << "#{declare} size_t #{identify}(const #{type}* self);"
    end

    def define_identify(stream) end; remove_method :define_identify

  end # Hashable


  # @abstract
  class Composite

    include Type
    include Module::Entity
    include MethodSynthesizer
    include DependencyComposer

    extend Redirector

    attr_reader :prefix

    def initialize(type, prefix, deps)
      super(type)
      @prefix = (prefix.nil? ? type : prefix).to_s
      self.dependencies = deps << CODE
    end

    #
    def decorate_method(symbol)
      method = symbol.to_s.sub(/[!?]$/, '') # Strip trailing ? or !
      # Check for leading underscore
      underscored = if /(_+)(.*)/ =~ method
                      method = $2
                      true
                    else
                      false
                    end
      function = prefix + method[0,1].capitalize + method[1..-1] # Ruby 1.8 compatible
      # Carry over the method name's leading underscore only if the prefix is not in turn underscored
      underscored && !(prefix[0] == '_') ? "#{$1}#{function}" : function
    end

    def inline; :AUTOC_INLINE end

    def static; :AUTOC_STATIC end

    def declare; :AUTOC_EXTERN end

    def define; end

    CODE = Code.interface %$
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

  end # Composite


  # User-defined value type.
  class Synthetic

    include Type
    include Module::Entity
    include MethodSynthesizer
    include DependencyComposer

    def initialize(type, deps: [], prefix: nil, interface: nil, declaration: nil, definition: nil, custom_create_params: [], **calls)
      super(type)
      @calls = calls
      @interface = interface
      @declaration = declaration
      @definition = definition
      deps.concat(self.custom_create_params = custom_create_params) if custom_constructible?
      self.dependencies = deps
    end

    undef_method :clone # Custom #clone shadows the Object#clone

    def default_constructible?
      !@calls[:default_create].nil?
    end

    def custom_constructible?
      !@calls[:custom_create].nil?
    end

    def destructible?
      !@calls[:destroy].nil?
    end

    def cloneable?
      !@calls[:clone].nil?
    end

    def movable?
      !@calls[:move].nil?
    end

    def equality_testable?
      !@calls[:equal].nil?
    end

    def comparable?
      equality_testable? && !@calls[:less].nil?
    end

    def hashable?
      equality_testable? && !@calls[:identify].nil?
    end

    NEW_LINE = "\n".freeze

    def interface(stream)
      stream << NEW_LINE << @interface << NEW_LINE unless @interface.nil?
    end

    def declaration(stream)
      stream << NEW_LINE << @declaration << NEW_LINE unless @declaration.nil?
    end

    def definition(stream)
      stream << NEW_LINE << @definition << NEW_LINE unless @definition.nil?
    end

    def decorate_method(symbol)
      raise ArgumentError, "unrecognized call `#{symbol}`" unless @calls.include?(symbol)
      @calls[symbol].to_s
    end

  end # Synthetic


  # Aggregate value type.
  class Structure < Composite

    include ConstructibleAdapter

    def initialize(type, prefix = nil, **fields)
      @fields = fields.transform_values {|e| Type.coerce(e)}
      super(type, prefix, @fields.values + [CODE])
      self.custom_create_params = @fields.values if custom_constructible?
    end

    %i(destroy).each {|s| redirect(s, 1)}
    %i(clone equal).each {|s| redirect(s, 2)}

    def constructible?
      @fields.each_value {|type| return false unless type.constructible?}
      true
    end

    def default_constructible?
      @fields.each_value {|type| return false unless type.default_constructible?}
      true
    end

    def custom_constructible?
      @fields.each_value {|type| return false unless type.cloneable?}
      true
    end

    def cloneable?
      @fields.each_value {|type| return false unless type.cloneable?}
      true
    end

    def equality_testable?
      @fields.each_value {|type| return false unless type.equality_testable?}
      true
    end

    def destructible?
      @fields.each_value {|type| return true if type.destructible?}
      false
    end

    def interface(stream)
      stream << "typedef struct #{type} #{type}; struct #{type} {"
        @fields.each {|field, element| stream << "#{element.type} #{field};"}
      stream << '};'
      #
      stream << "#{declare} #{type}* #{send(@default_create)}(#{type}* self);" if default_constructible?
      stream << "#{declare} #{type}* #{send(@custom_create)}(#{type}* self, #{custom_create_params.declare});" if custom_constructible?
      stream << "#{declare} #{type}* #{clone}(#{type}* self, const #{type}* origin);" if cloneable?
      stream << "#{declare} void #{destroy}(#{type}* self);" if destructible?
      stream << "#{declare} int #{equal}(const #{type}* self, const #{type}* other);" if equality_testable?
    end

    def definition(stream)
      if default_constructible?
        stream << "#{define} #{type}* #{send(@default_create)}(#{type}* self) { assert(self);"
          @fields.each {|field, element| stream << element.default_create("self->#{field}") << ';'}
        stream << 'return self;}'
      end
      if custom_constructible?
        stream << "#{define} #{type}* #{send(@custom_create)}(#{type}* self, #{custom_create_params.declare}) { assert(self);"
        list = custom_create_params.pass_list
        i = -1; @fields.each {|field, element| stream << element.clone("self->#{field}", list[i+=1]) << ';'}
        stream << 'return self;}'
      end
      if cloneable?
        stream << "#{define} #{type}* #{clone}(#{type}* self, const #{type}* origin) { assert(self); assert(origin);"
          @fields.each {|field, element| stream << element.clone("self->#{field}", "origin->#{field}") << ';'}
        stream << 'return self;}'
      end
      if destructible?
        stream << "#{define} void #{destroy}(#{type}* self) { assert(self);"
          @fields.each {|field, element| stream << element.destroy("self->#{field}") << ';' if element.destructible?}
        stream << '}'
      end
      if equality_testable?
        stream << "#{define} int #{equal}(const #{type}* self, const #{type}* other) { assert(self); assert(other);"
        xs = []; @fields.each {|field, element| xs << element.equal("self->#{field}", "other->#{field}")}
        s = ['self == other', "(#{xs.join(' && ')})"].join(' || ')
        stream << "return #{s};}"
      end
    end

    CODE = Code.interface %$
      #include <assert.h>
    $

    #
    module Hashable

      include AutoC::Hashable

      def initialize(*args, **kws)
        super(*args, **kws)
        raise TraitError, 'including type must be a Structure descendant' unless is_a?(Structure)
        raise TraitError, 'structure has non-hashable field(s)' unless hashable?
      end

      def hashable?
        @fields.each_value {|type| return false unless type.hashable?}
        true
      end

      def define_identify(stream)
        stream << %$
        #{define} size_t #{identify}(const #{type}* self) {
          size_t hash;
          #{hasher.type} hasher;
          assert(self);
          #{hasher.create(:hasher)};
      $
        @fields.each {|field, element| stream << hasher.update(:hasher, element.identify("self->#{field}")) << ';'}
        stream << %$
          hash = #{hasher.result(:hasher)};
          #{hasher.destroy(:hasher)};
          return hash;
        }
      $
      end

    end # Hashable

  end # Structure


  # @abstract
  class Container < Composite

    attr_reader :element

    def initialize(type, element, prefix, deps)
      @weak = [] # Dependencies with back references to self do create dependency cycles and hence must be excluded from comparison
      @element = Type.coerce(element)
      super(type, prefix, deps << self.element << CODE)
    end

    def <=>(other)
      @weak.include?(other) ? -1 : super
    end

    def constructible?
      true
    end

    def destructible?
      true
    end

    def cloneable?
      element.cloneable?
    end

    def equality_testable?
      element.equality_testable?
    end

    CODE = Code.interface %$
      #include <assert.h>
      #include <stddef.h>
      #include <malloc.h>
    $

    #
    module Hashable

      include AutoC::Hashable

      def initialize(*args, **kws)
        super(*args, **kws)
        @weak << range
        dependencies << hasher << range
        raise TraitError, 'including type must be a Container descendant' unless is_a?(Container)
        raise TraitError, 'container element must be hashable' unless element.hashable?
      end

      def hashable?
        element.hashable?
      end

      def define_identify(stream)
        stream << %$
        #{define} size_t #{identify}(const #{type}* self) {
          #{hasher.type} hasher;
          #{range.type} range;
          size_t hash;
          assert(self);
          #{hasher.create(:hasher)};
          #{range.create(:range, :self)};
          for(; !#{range.empty(:range)}; #{range.popFront(:range)}) {
            const #{element.type}* e = #{range.frontView(:range)};
            #{hasher.update(:hasher, element.identify('*e'))};
          }
          hash = #{hasher.result(:hasher)};
          #{hasher.destroy(:hasher)};
          return hash;
        }
      $
      end

    end # Hashable

  end # Container


  # @abstract
  class AssociativeContainer < Container

    attr_reader :key

    def initialize(type, key, element, prefix, deps)
      @key = Type.coerce(key)
      super(type, element, prefix, deps << key)
    end

    def copyable?
      super && key.copyable?
    end

    def equality_testable?
      super && key.equality_testable?
    end

  end # AssociativeContainer


end # AutoC