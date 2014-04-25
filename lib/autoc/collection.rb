require "autoc/code"
require "autoc/type"


module AutoC


class Collection < Type
  
  def self.coerce(type)
    type.is_a?(Type) ? type : UserDefinedType.new(type)
  end
  
  attr_reader :element
  
  def entities; super + [element] end
  
  def initialize(type_name, element_type, visibility = :public)
    super(type_name, visibility)
    @element = Collection.coerce(element_type)
  end
  
  def ctor(*args)
    if args.empty?
      super()
    else
      check_args(args, 1)
      obj = args.first
      super() + "(&#{obj})"
    end
  end
  
  def dtor(*args)
    if args.empty?
      super()
    else
      check_args(args, 1)
      obj = args.first
      super() + "(&#{obj})"
    end
  end
  
  def copy(*args)
    if args.empty?
      super()
    else
      check_args(args, 2)
      dst, src = args
      super() + "(&#{dst}, &#{src})"
    end
  end
  
  def equal(*args)
    if args.empty?
      super()
    else
      check_args(args, 2)
      lt, rt = args
      super() + "(&#{lt}, &#{rt})"
    end
  end
  
  def less(*args)
    args.empty? ? super() : raise("#{self.class} provides no ordering functionality")
  end
  
  def identify(*args)
    args.empty? ? super() : raise("#{self.class} provides no hashing functionality")
  end
  
  private
  
  def check_args(args, nargs)
    raise "expected exactly #{nargs} argument(s)" unless args.size == nargs
  end
  
end # Collection


end # AutoC