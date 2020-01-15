require 'autoc/module'


module AutoC


  # @abstract
  module Type

    #
    def self.coerce(obj)
      obj.is_a?(Type) ? obj : PrimitiveType.new(obj)
    end

    #
    attr_reader :type

    def initialize(type)
      @type = type.to_s.freeze
    end

    def ==(other)
      type == other.type
    end

    def eql?(other)
      self.class.eql?(other.class) && type.eql?(other.type)
    end

    def hash
      type.hash
    end

    #
    def create(value, *args) end; remove_method :create

    #
    def destroy(value) end; remove_method :destroy

    #
    def copy(value, origin) end; remove_method :copy

    #
    def equal(value, other) end; remove_method :equal

    #
    def less(value, other) end; remove_method :less

    #
    def identify(value) end; remove_method :identify

    # Type traits

    def constructible?
      respond_to?(:create)
    end

    def default_constructible?
      !create(:value).nil?
    rescue
      false
    end

    def destructible?
      respond_to?(:destroy)
    end

    def copyable?
      respond_to?(:copy)
    end

    def comparable?
      respond_to?(:equal) && respond_to?(:less)
    end

    def hashable?
      respond_to?(:equal) && respond_to?(:identify)
    end
  end


  #
  class PrimitiveType

    include Type

    include Module::Entity

    def create(value, *args)
      init = case args.length
             when 0
               0
             when 1
               args.first
             else
               raise ArgumentError, 'expected at most one initializer'
      end
      "(#{value}) = (#{init})"
    end

    def copy(value, origin)
      "(#{value}) = (#{origin})"
    end

    def equal(value, other)
      "(#{value}) == (#{origin})"
    end

    def less(value, other)
      "(#{value}) < (#{origin})"
    end

    def identify(value)
      "((size_t)#{value})"
    end

  end # Type

end # AutoC