require 'autoc/module'


module AutoC


  #
  class TraitError < TypeError; end # TraitError


  #
  module Type

    #
    def self.coerce(obj)
      obj.is_a?(Type) ? obj : Primitive.new(obj)
    end

    #
    attr_reader :type

    def initialize(type)
      @type = type
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

    #
    def constructible?
      respond_to?(:create)
    end

    #
    def auto_constructible?
      constructible? && create_params.size.zero?
    end

    #
    def destructible?
      respond_to?(:destroy)
    end

    #
    def copyable?
      respond_to?(:copy)
    end

    #
    def equality_testable?
      respond_to?(:equal)
    end

    #
    def comparable?
      equality_testable? && respond_to?(:less)
    end

    #
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
  class Derived

    include Type
    include Module::Entity

    attr_reader :dependencies

    def initialize(type, prefix, deps)
      super(type)
      @prefix = prefix.to_s unless prefix.nil?
      @dependencies = Set[*deps].freeze
    end

    def prefix
      @prefix ||= type.to_s
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

  end # Derived


  #
  module Redirecting
    def def_redirector(meth, redirect_args = 0)
      class_eval %~
        def #{meth}(*args)
          if args.size == 1 && args.first.nil?
            method_missing(:#{meth}, nil)
          else
            n = [#{redirect_args}, args.size].min
            ls = (n.zero? ? args : args[0..n-1]).collect {|arg| %"&\#{arg}"}
            rs = n.zero? ? [] : args[n..-1]
            method_missing(:#{meth}, *(ls + rs))
          end
        end
      ~
    end
  end


  #
  class Composite < Derived

    extend Redirecting

    def initialize(type, prefix, deps)
      super(type, prefix, deps << CODE)
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


  #
  class Synthetic < Derived

    attr_reader :create_params

    def initialize(type, deps: [], prefix: nil, interface: nil, declaration: nil, definition: nil, create_params: [], **calls)
      @calls = calls
      @interface = interface
      @declaration = declaration
      @definition = definition
      @create_params = create_params.collect {|e| Type.coerce(e)}
      super(type, prefix, deps.collect {|e| Type.coerce(e)} + @create_params)
    end

    def constructible?
      !@calls[:create].nil?
    end

    def destructible?
      !@calls[:destroy].nil?
    end

    def copyable?
      !@calls[:copy].nil?
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

    NEW_LINE = "\n"

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


  #
  class Structure < Composite

    def initialize(type, auto_create = false, prefix = nil, **fields)
      @fields = fields.transform_values {|e| Type.coerce(e)}
      super(type, prefix, @fields.values + [CODE])
      if (@auto_create = auto_create)
        raise TraitError, 'can not create auto constructor due to present non-auto constructible field(s)' unless fields_auto_constructible?
      else
        raise TraitError, 'can not create initializing constructor due to present non-copyable field(s)' unless fields_copyable?
      end
    end

    %i(create createEx destroy).each {|s| def_redirector(s, 1)}
    %i(copy equal).each {|s| def_redirector(s, 2)}

    alias createAuto create

    def create(*args)
      @auto_create ? createAuto(*args) : createEx(*args)
    end

    def create_params
      @auto_create ? [] : @fields.values
    end

    def constructible?
      fields_constructible?
    end

    def auto_constructible?
      fields_auto_constructible?
    end

    def copyable?
      fields_copyable?
    end

    def equality_testable?
      fields_equality_testable?
    end

    def destructible?
      fields_destructible?
    end

    def create_params_declare_list
      xs = []
      @fields.each {|field, element| xs << "#{element.type} #{field}"}
      xs
    end

    def create_params_pass_list
      @fields.keys
    end

    def interface(stream)
      stream << "typedef struct #{type} #{type}; struct #{type} {"
        @fields.each {|field, element| stream << "#{element.type} #{field};"}
      stream << '};'
      #
      stream << "#{declare} #{type}* #{createAuto}(#{type}* self);" if auto_constructible?
      stream << %$
        #{declare} #{type}* #{createEx}(#{type}* self, #{create_params_declare});
        #{declare} #{type}* #{copy}(#{type}* self, const #{type}* origin);
      $ if copyable?
      stream << "#{declare} void #{destroy}(#{type}* self);" if destructible?
      stream << "#{declare} int #{equal}(const #{type}* self, const #{type}* other);" if equality_testable?
    end

    def definition(stream)
      if auto_constructible?
        stream << "#{define} #{type}* #{createAuto}(#{type}* self) { assert(self);"
          @fields.each {|field, element| stream << element.create("self->#{field}") << ';'}
        stream << 'return self;}'
      end
      if copyable?
        stream << "#{define} #{type}* #{createEx}(#{type}* self, #{create_params_declare}) { assert(self);"
          @fields.each {|field, element| stream << element.copy("self->#{field}", field) << ';'}
        stream << 'return self;}'
        stream << "#{define} #{type}* #{copy}(#{type}* self, const #{type}* origin) { assert(self); assert(origin);"
          @fields.each {|field, element| stream << element.copy("self->#{field}", "origin->#{field}") << ';'}
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

    private

    def fields_constructible?
      @fields.each_value {|type| return false unless type.constructible?}
      true
    end

    def fields_auto_constructible?
      @fields.each_value {|type| return false unless type.auto_constructible?}
      true
    end

    def fields_copyable?
      @fields.each_value {|type| return false unless type.copyable?}
      true
    end

    def fields_equality_testable?
      @fields.each_value {|type| return false unless type.equality_testable?}
      true
    end

    def fields_destructible?
      @fields.each_value {|type| return true if type.destructible?}
      false
    end

  end # Structure


  #
  class Container < Composite

    attr_reader :element

    def initialize(type, element, prefix, deps)
      @weak = [] # Dependencies with back references to self which create dependency cycles and thus must be excluded from comparison
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

    def copyable?
      element.copyable?
    end

    def equality_testable?
      element.equality_testable?
    end

    CODE = Code.interface %$
      #include <assert.h>
      #include <stddef.h>
      #include <malloc.h>
    $

  end # Container


  #
  module Container::Hashable

    extend Redirecting
    def_redirector :identify, 1

    def hasher
      AutoC::Hasher.default
    end

    def initialize(*args, **kws)
      kws[:deps] = (deps = kws[:deps]).nil? ? [hasher, range] : deps << hasher << range
      super(*args, **kws)
      @weak << range
      raise TraitError, 'enclosing class must be a Container descendant' unless is_a?(Container)
      raise TraitError, 'container element must be hashable' unless element.hashable?
    end

    def interface(stream)
      super
      stream << %$
        #{declare} size_t #{identify}(const #{type}* self);
      $
    end

    def definition(stream)
      super
      define_identify(stream)
    end

    private

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


  #
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