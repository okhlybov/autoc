module AutoC


# :nodoc:
module Iterators


# :nodoc:
module Unidirectional
  def write_intf_decls(stream, declare, define)
    super
    stream << %$
      #{declare} void #{itCtor}(#{it_ref}, #{type_ref});
      #{declare} int #{itMove}(#{it_ref});
      #{declare} #{element.type} #{itGet}(#{it_ref});
    $
  end
end


# :nodoc:
module Bidirectional
  def write_intf_decls(stream, declare, define)
    super
    stream << %$
      #define #{itCtor}(self, type) #{itCtorEx}(self, type, 1)
      #{declare} void #{itCtorEx}(#{it_ref}, #{type_ref}, int);
      #{declare} int #{itMove}(#{it_ref});
      #{declare} #{element.type} #{itGet}(#{it_ref});
    $
  end
end


end # Iterators


end # AutoC