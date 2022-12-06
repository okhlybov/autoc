# frozen_string_literal: true


module AutoC


  # @abstract
  class Type

    # C side type signature
    attr_reader :signature

    def self.abstract(method) = remove_method(method)

    def initialize(signature) = @signature = signature.to_s

    def to_type = self

    def to_s = signature

    def inspect = "#{signature} <#{self.class}>"

    # def lvalue()
    # def rvalue()
    # def const_lvalue()
    # def const_rvalue()

    # @abstract
    # Synthesize the source side code to create an instance in place of the +value+ and perform its default
    # initialization (the default constructor).
    #
    # Original contents of the +value+ is overwritten.
    #
    # @param value [String | Symbol] source side storage designation where the instance is to be created
    # @return [String] source side code snippet
    abstract def default_create(value) = ABSTRACT

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
    abstract def custom_create(value, *args) = ABSTRACT

    # @abstract
    # Synthesize the source side code to destroy the instance in place of the +value+ (the destructor).
    #
    # @param value [String | Symbol] source side storage designation for the instance to be destroyed
    # @return [String] source side code snippet
    abstract def destroy(value) = ABSTRACT

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
    abstract def copy(value, source) = ABSTRACT

    # @abstract TODO
    abstract def equal(value, other) = ABSTRACT

    # @abstract TODO
    abstract def compare(value, other) = ABSTRACT

    # @abstract TODO
    abstract def hash_code(value) = ABSTRACT

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

  end # Type


end