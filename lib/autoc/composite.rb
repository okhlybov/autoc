# frozen_string_literal: true


require 'autoc/core'
require 'autoc/module'
require 'autoc/decorator'


module AutoC


class Composite
  
  include Entity

  include Decorator

  alias prefix_c name_c

end


end