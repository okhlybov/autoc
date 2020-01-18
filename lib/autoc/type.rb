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

  end # PrimitiveType


  #
  class ValueType

    include Type

    include Module::Entity

    attr_reader :dependencies

    def initialize(type, deps)
      super(type)
      @dependencies = Set.new(deps).freeze
    end

    #
    def self.def_redirector(meth)
      class_eval %~
        def #{meth}(*args)
          method_missing(:#{meth}, *args.collect {|arg| %"&(\#{arg})"})
        end
      ~
    end

    def method_missing(symbol, *args)
      function = decorate_method(symbol) # Construct C function name for the method
      if args.empty?
        function # Emit bare function name
      elsif args.size == 1 && args.first == nil
        function + '()' # Use sole nil argument to emit function call with no arguments
      else
        function + '(' + args.join(',') + ')' # Emit normal function call with supplied arguments
      end
    end

    private

    #
    def decorate_method(symbol)
      method = symbol.to_s
      method = method.sub(/[!?]$/, '') # Strip trailing ? or !
      # Check for leading underscore
      underscored = if /_(.*)/ =~ method
                     method = $1
                     true
                    else
                     false
                    end
      function = type + method[0,1].capitalize + method[1..-1] # Ruby 1.8 compatible
      underscored ? "_#{function}" : function # Preserve the leading underscore
    end

  end # CustomValueType


  #
  class Collection < ValueType

    attr_reader :element_type

    def initialize(type, element_type, deps)
      super(type, deps)
      @element_type = Type.coerce(element_type)
    end

  end # Collection

end # AutoC