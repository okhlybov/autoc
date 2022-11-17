# frozen_string_literal: true


require 'autoc/module'


module AutoC

  module TypeCoercer
    def to_type = AutoC::Type.coerce(self)
    def lvalue = to_type.lvalue
    def rvalue = to_type.rvalue
    def const_rvalue = to_type.const_rvalue
    def parameter = to_type.parameter
    def ~@ = "*#{self}"
  end

  class ::String
    include TypeCoercer
  end

  class ::Symbol
    include TypeCoercer
  end

  class Parameter
    attr_reader :type
    def to_s = type.to_s
    def to_type = type
    def initialize(type, constant: false, kind: :value)
      @type = type
      @constant = constant
      @kind = kind
    end
    def constant? = @constant == true
    def value? = @kind == :value
    def reference? = @kind == :reference
    def parameter = self
    def declare
      t = reference? ? "#{to_s}*" : to_s
      constant? ? "const #{t}" : t
    end
    def pass(value)
      reference? ? "&(#{value})" : value.to_s
    end
  end

  # Generator class for standalone function
  class Function

    # Parameter

    #
    attr_reader :name

    #
    attr_reader :result

    #
    attr_reader :parameters

    def initialize(name, parameters = [], result = :void, inline: false, visibility: :public, requirement: true)
      @name = name.to_s
      @result = result.to_type
      @requirement = requirement
      @inline = inline
      @visibility = visibility
      @parameters =
        if parameters.is_a?(Hash)
          hash = {}
          parameters.each { |name, parameter| hash[name.to_sym] = parameter.parameter }
          hash
        else
          hash = {}
          (0..parameters.size-1).each { |i| hash["__#{i}__".to_sym] = parameters[i].parameter }
          hash
        end
    end

    def inline? = @inline == true

    def public? = @visibility == :public
  
    def live? = (@requirement.is_a?(Proc) ? @requirement.() : @requirement) == true
  
    def to_s = name

    def signature = '%s(%s)' % [result, parameters.values.collect(&:declare).join(',')]

    def declaration = '%s %s(%s)' % [result, name, parameters.collect { |var, type| "#{type.declare} #{var}" }.join(', ')]

    def pointer(name) = '%s(*%s)(%s)' % [result, name, parameters.values.collect(&:declare).join(',')]

    def call(*arguments)
      if arguments.empty?
        self
      else
        if arguments.first.nil?
          "#{name}()"
        else
          formals = parameters.to_a
          '%s(%s)' % [name, (0..arguments.size-1).collect { |i| i < formals.size ? formals[i].last.pass(arguments[i]) : arguments[i] }.join(', ')]
        end
      end
    end

    def inline
      @inline = true
      self
    end

    def external
      @inline = false
      self
    end

    def header(header) = @header = header

    def code(code) = @code = code

  end # Function


  # Type-bound function (aka method) generator
  class Method < Function
    attr_reader :type
    def initialize(type, name, *args, **kws)
      super(type.decorate_identifier(name), *args, **kws)
      @type = type
    end
    def method_missing(meth, *args) = type.send(meth, *args)
  end # Method


  # @abstract
  # Base class for type generators
  class Type

    include Entity

    def self.abstract(meth) = remove_method(meth)

    #
    def self.coerce(obj) = obj.is_a?(Type) ? obj : Primitive.new(obj)

    # C side type signature suitable for generating variable declarations.
    # This implementation sports lazy type definition based on the value supplied at object construction time.
    attr_reader :type

    #
    attr_reader :ptr_type

    #
    attr_reader :const_type

    #
    attr_reader :const_ptr_type

    #
    def to_s = type.to_s

    #
    def to_type = self

    def initialize(type)
      @type = type
      @ptr_type = "#{type}*"
      @const_type = "const #{type}"
      @const_ptr_type = "const #{type}*"
    end

    # @abstract
    # Synthesize the source side code to create an instance in place of the +value+ and perform its default
    # initialization (the default constructor).
    #
    # Original contents of the +value+ is overwritten.
    #
    # @param value [String | Symbol] source side storage designation where the instance is to be created
    # @return [String] source side code snippet
    abstract def default_create(value) = nil

    # @abstract
    # Synthesize the source side code to create an instance in place of the +value+ and and initialize it with
    # supplied +args+ (the custom constructor).
    #
    # The +args+ elements are expected to be of the {Type} type.
    #
    # Original contents of the +value+ is overwritten.
    #
    # @param value [String | Symbol] source side storage designation where the instance is to be created
    # @param args [Array] list of types to be supplied to the constructor
    # @return [String] source side code snippet
    abstract def custom_create(value, *args) = nil

    # @abstract
    # Synthesize the source side code to destroy the instance in place of the +value+ (the destructor).
    #
    # @param value [String | Symbol] source side storage designation for the instance to be destroyed
    # @return [String] source side code snippet
    abstract def destroy(value) = nil

    # @abstract
    # Synthesize the source side code to create an instance in place of the +value+ initializing it with a contents of
    # the +origin+ instance (the copy constructor).
    #
    # Original contents of the +value+ is overwritten.
    # The contents of the +source+ is left intact.
    #
    # @param value [String | Symbol] source side storage designation where the instance is to be created
    # @param source [String | Symbol] source side storage designation taken as the origin for the copying operation
    # @return [String] source side code snippet
    abstract def copy(value, source) = nil

    # @abstract TODO
    abstract def equal(value, other) = nil

    # @abstract TODO
    abstract def compare(value, other) = nil

    # @abstract TODO
    abstract def hash_code(value) = nil

    # @abstract TODO replace value with a copy of source destroying prevous contents
    # abstract def replace(value,  source) = nil

    # Test whether the type has a default (parameterless) constructor.
    # This implementation looks up the {#default_create} method.
    def default_constructible? = respond_to?(:default_create)

    # Test whether the type has a custom constructor which accepts a number of parameters.
    # This implementation looks up the {#custom_create} method.
    def custom_constructible? = respond_to?(:custom_create)

    # Test whether the type can be constructed, with either default or parametrized initialization.
    # This implementation queries {#custom_constructible?} and {#default_constructible?}.
    def constructible? = custom_constructible? || default_constructible?

    # Test whether the type has a non-trivial destructor.
    # This implementation looks up the {#destroy} method.
    def destructible? = respond_to?(:destroy)

    # Test whether the type can be created from an instance of the same type (cloned).
    # This implementation looks up the {#copy} method.
    def copyable? = respond_to?(:copy)

    # Test whether the type has a well-defined test for content equality against another value of the same type.
    # This implementation looks up the {#equal} method.
    def comparable? = respond_to?(:equal)

    # Test whether the type can be compared for less-equal-more against another value of the same type.
    # Orderable type's values can be sorted and put into tree-based containers.
    # For the type to be comparable this implementation looks up the {#compare} method.
    def orderable? = respond_to?(:compare)

    # Test whether the type's values which can be the elements of hash-based containers.
    def hashable? = comparable? && respond_to?(:hash_code)

    # TODO movable semantics

  end # Type


  # Generator type for wrappers of primitive C types such as numbers, bare pointers etc.
  class Primitive < Type

    def default_create(value) = custom_create(value, 0)

    def custom_create(value, initial) = copy(value, initial)

    def copy(value, source) = "(#{value} = #{source})"

    def equal(lt, rt) = "(#{lt} == #{rt})"

    def compare(lt, rt) = "(#{lt} == #{rt} ? 0 : (#{lt} > #{rt} ? +1 : -1))"

    def hash_code(value) = "(size_t)(#{value})"

    def parameter = rvalue

    def lvalue = @lv ||= Parameter.new(self, kind: :reference)

    def rvalue = @rv ||= Parameter.new(self)

    def const_rvalue = @crv ||= Parameter.new(self, constant: true)

  end # Primitive


  # Generator type for pure user-defined types
  class Synthetic < Type

    def initialize(type, dependencies: [], interface: nil, declarations: nil, definitions: nil, **call)
      super(type)
      @call = {}
      @interface_ = interface
      @declarations_ = declarations
      @definitions_ = definitions
      self.dependencies.merge(dependencies)
      def_call(call, :custom_create, nil, nil)
      def_call(call, :default_create, { self: type} , type)
      def_call(call, :destroy, { self: type }, :void)
      def_call(call, :copy, { self: type, source: const_type }, type)
      def_call(call, :equal, { self: const_type, other: const_type }, :int)
      def_call(call, :compare, { self: const_type, other: const_type }, :int)
      def_call(call, :hash_code, { self: const_type }, :size_t)
    end

    private def def_call(call, meth, args, result)
      unless call[meth].nil?
        @call[meth] =
          case call[meth]
          when AutoC::Function then call[meth] # Function instance is used as is. Beware of incompatible signatures!
          else args.nil? ? raise('AutoC::Function instance is expected') : AutoC::Function.new(call[meth], args, result) # A new function with specific signature is created
          end
      end
    end

    def respond_to_missing?(*args) = @call.include?(args.first) ? !@call[args.first].nil? : super

    def method_missing(symbol, *args) = @call.include?(symbol) && !@call[symbol].nil? ? @call[symbol][*args] : super

    def interface_declarations(stream)
      super
      stream << @interface_ unless @interface_.nil?
    end

    def forward_declarations(stream)
      super
      stream << @declarations_ unless @declarations_.nil?
    end

    def definitions(stream)
      super
      stream << @definitions_ unless @definitions_.nil?
    end

  end # Synthetic


end