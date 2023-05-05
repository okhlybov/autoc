require 'autoc/module'
require 'autoc/composite'


module AutoC


  # Lifetime manager of attached instances
  class Lifetime

    include Entity

    def initialize = dependencies << Composite::DEFINITIONS

    def <<(entity) = references << entity

  end # Lifetime


  # Value instance entity
  class Lifetime::Instance

    include AutoC::Entity

    @@index = 0

    attr_reader :type, :name

    def to_s = name

    def automatic? = @automatic

    def public? = !automatic?

    def initialize(type, name = nil)
      @type = type.to_type
      @automatic = name.nil?
      @name = automatic? ? "_#{type}#{@@index+=1}" : name
      dependencies << self.type << Composite::DEFINITIONS
    end

    def render_interface(stream)
      unless public?
        stream 
      end
      stream << %{
        AUTOC_EXTERN #{type} #{name};
      }
    end

    def render_implementation(stream)
      stream << %{
        #{type} #{name};
      }
    end

    #def within_problem(problem) = problem.instances << self
    
    def method_missing(symbol, *args, **kws)
      # Return proxy lambda which inserts this instance object as the first (target) argument into argument list
      # This allows to mimic method call foo.bar(a,b,c) which translates in the C side to bar(foo,a,b,c)
      proc { |*args, **kws| type.send(symbol).call(self, *args, **kws) }
    end

  end # Instance


end