require 'autoc/variant'

type_test(AutoC::Variant, :CharVariant, {c: :char, v: Value}) do

  #

  setup %{ #{type} t; }

  test :create_default, %{
  }

end