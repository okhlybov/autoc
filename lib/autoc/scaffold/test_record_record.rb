require 'autoc/record'

require_relative 'glass_record'

t = type_test(AutoC::Record, :RecordRecord, { r: GlassRecord }) do

  ###

  setup %{
    #{self} t;
    #{default_create.(:t)};
  }

  cleanup %{
    #{destroy.(:t) if destructible?};
  }

  test :create_empty, %{
  }

end