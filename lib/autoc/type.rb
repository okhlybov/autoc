require 'autoc/module'


module AutoC


  #
  module Type

    #
    def self.coerce(obj)
      obj.is_a?(Type) ? obj : Primitive.new(obj)
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
    def create_params_declare_list
      i = 0; create_params.collect{|p| "#{p} _#{i+=1}"}
    end

    #
    def create_params_declare
      create_params_declare_list.join(',')
    end

    #
    def create_params_pass_list
      (1..create_params.size).collect {|i| "_#{i}"}
    end

    #
    def create_params_pass
      create_params_pass_list.join(',')
    end

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

    # Type trait tests

    def constructible?
      respond_to?(:create)
    end

    def destructible?
      respond_to?(:destroy)
    end

    def copyable?
      respond_to?(:copy)
    end

    def equality_testable?
      respond_to?(:equal)
    end

    def orderable?
      equality_testable? && respond_to?(:less)
    end

    def hashable?
      respond_to?(:equal) && respond_to?(:identify)
    end

  end


  #
  class Primitive

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

    EMPTY_ARRAY = [].freeze

    def create_params; EMPTY_ARRAY end

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

  end # Primitive


  #
  class Composite

    include Type

    include Module::Entity

    attr_reader :prefix, :dependencies

    def initialize(type, prefix: nil, deps: [])
      super(type)
      @prefix = (prefix.nil? ? self.type : prefix).to_s
      @dependencies = Set[CODE, *deps].freeze
    end

    alias to_s prefix

    def inline; :AUTOC_INLINE end

    def declare; :AUTOC_EXTERN end

    def define; end

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

    CODE = Code.interface %$
      #ifndef AUTOC_INLINE
        #if __STDC_VERSION__ >= 199901L || defined(__cplusplus)
          #define AUTOC_INLINE inline
        #else
          #define AUTOC_INLINE static
        #endif
      #endif
      #ifndef AUTOC_EXTERN
        #if defined(__cplusplus)
          #define AUTOC_EXTERN extern "C"
        #else
          #define AUTOC_EXTERN extern
        #endif
      #endif
    $

  end # Composite


  class Structure < Composite

    def initialize(type, **fields)
      @fields = fields.transform_values {|e| Type.coerce(e)}
      super(type, deps: @fields.values)
      # TODO type traits conformance tests
    end

    def default_create!
      raise 'Type has no default constructor' unless default_constructible?
      @default_create = true
      self
    end

    # TODO
    #def_redirector(:create, 1)

    def create_params
      @fields.values
    end

    def constructible?
      @fields.each_value {|type| return false unless type.constructible?}
      true
    end

    def default_constructible?
      @fields.each_value {|type| return false unless type.create_params.size.zero?}
      true
    end

    def copyable?
      @fields.each_value {|type| return false unless type.copyable?}
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

    def create_params_declare_list
      xs = []
      @fields.each {|field, type| xs << "#{type} #{field}"}
      xs
    end

    def create_params_pass_list
      @fields.keys
    end

    def interface(stream)
      stream << "typedef struct {"
        @fields.each {|field, type| stream << "#{type} #{field};"}
      stream << "} #{self};"
      #
      stream << "void #{create}(#{self}* self);" if default_constructible?
      stream << %$
        #{declare} void #{createEx}(#{self}* self, #{create_params_declare});
        #{declare} void #{copy}(#{self}* self, #{self}* origin);
      $ if copyable?
      stream << "#{declare} void #{destroy}(#{self}* self);" if destructible?
      stream << "#{declare} int #{equal}(#{self}* self, #{self}* other);" if equality_testable?
    end

    def definition(stream)
      if default_constructible?
        stream << "#{define} void #{create}(#{self}* self) { assert(self);"
          @fields.each {|field, type| stream << type.create("self->#{field}") << ';'}
        stream << '}'
      end
      if copyable?
        stream << "#{define} void #{createEx}(#{self}* self, #{create_params_declare}) { assert(self);"
          @fields.each {|field, type| stream << type.copy("self->#{field}", field) << ';'}
        stream << '}'
        stream << "#{define} void #{copy}(#{self}* self, #{self}* origin) { assert(self); assert(origin);"
          @fields.each {|field, type| stream << type.copy("self->#{field}", "origin->#{field}") << ';'}
        stream << '}'
      end
      if destructible?
        stream << "#{define} void #{destroy}(#{self}* self) { assert(self);"
          @fields.each {|field, type| stream << type.destroy("self->#{field}") << ';' if type.destructible?}
        stream << '}'
      end
      if equality_testable?
        stream << "#{define} int #{equal}(#{self}* self, #{self}* other) { assert(self); assert(other);"
        xs = []; @fields.each {|field, type| xs << type.equal("self->#{field}", "other->#{field}")}
        s = ['self == other', xs.join(' && ')].join(' || ')
        stream << "return #{s};}"
      end
    end

  end # Structure


end # AutoC