require 'autoc/module'
require 'autoc/primitive'
require 'autoc/composable'


module AutoC
  

using self


class Reference < Type::Indirection
  
  include Composable

  def prefix_c = @prefix.nil? ? type.prefix_c : @prefix

  def initialize(type, prefix: nil)
    super(type)
    @prefix = prefix&.to_s
    dependencies << self.type
  end

  def destructible? = true

  private def configure
    this = self
    method(:void, :new, { target: out(type) }, respond_to: :default_create, constraint: -> { default_constructible? }).configure do
      code %{
        *target = malloc(sizeof(#{this.type}));
        #{this.type.default_create.(parameters[:target])};
      }
    end
    method(:void, :free, { target: inout(type) }, respond_to: :destroy, constraint: -> { destructible? }).configure do
      code %{
        #{this.type.destroy.(parameters[:target]) if this.type.destructible?};
        free(target);
      }
    end
  end

end


end