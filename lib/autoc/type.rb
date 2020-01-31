require 'singleton'


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
      @type = type.to_s
    end

    alias to_s type

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
    attr_reader :create_params; remove_method :create_params

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

    def create_params; [] end

    def copy(value, origin)
      "(#{value}) = (#{origin})"
    end

    def equal(value, other)
      "(#{value}) == (#{other})"
    end

    def less(value, other)
      "(#{value}) < (#{other})"
    end

    def identify(value)
      "((size_t)#{value})"
    end

  end # PrimitiveType


  #
  class CompositeType

    include Type

    include Module::Entity

    attr_reader :prefix, :dependencies

    def initialize(type, prefix: nil, deps: [])
      super(type)
      @prefix = (prefix.nil? ? self.type : prefix).to_s
      @dependencies = Set[*(deps << Code.instance)].freeze
    end

    alias to_s prefix

    def inline; :AUTOC_INLINE end

    #
    def self.def_redirector(meth, redirect_args = 0)
      class_eval %~
        def #{meth}(*args)
          n = #{redirect_args}
          ls = (n.zero? ? args : args[0..n-1]).collect {|arg| %"&(\#{arg})"}
          rs = n.zero? ? [] : args[n..-1]
          method_missing(:#{meth}, *(ls + rs))
        end
      ~
    end

    #
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
      function = prefix + method[0,1].capitalize + method[1..-1] # Ruby 1.8 compatible
      underscored ? "_#{function}" : function # Preserve the leading underscore
    end

    class Code
      include Singleton
      include Module::Entity
      def interface(stream)
        stream << %$
          #ifndef AUTOC_INLINE
            #if __STDC_VERSION__ >= 199901L || defined(__cplusplus)
              #define AUTOC_INLINE inline
            #else
              #define AUTOC_INLINE static
            #endif
          #endif
        $
      end
    end # Code

  end # CompositeType


end # AutoC