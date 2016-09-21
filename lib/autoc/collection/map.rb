module AutoC

# :nodoc:
module Maps

  def write_intf_types(stream)
    super
    stream << %$
      /***
      **** #{type}<#{key.type} -> #{value.type}>
      ***/
    $ if public?
  end

  def write_intf_decls(stream, declare, define)
    super
    stream << %$
      #{declare} #{ctor.declaration};
      #{declare} #{dtor.declaration};
      #{declare} #{copy.declaration};
      #{declare} #{equal.declaration};
      #{declare} #{identify.declaration};
      #{declare} void #{purge}(#{type_ref});
      #{declare} size_t #{size}(#{type_ref});
      #define #{empty}(self) (#{size}(self) == 0)
      #{declare} int #{containsKey}(#{type_ref}, #{key.type});
      #{declare} #{value.type} #{get}(#{type_ref}, #{key.type});
      #{declare} int #{put}(#{type_ref}, #{key.type}, #{value.type});
      #{declare} int #{replace}(#{type_ref}, #{key.type}, #{value.type});
      #{declare} int #{remove}(#{type_ref}, #{key.type});
      #{declare} int #{itMove}(#{it_ref});
      #{declare} #{key.type} #{itGetKey}(#{it_ref});
      #{declare} #{value.type} #{itGetElement}(#{it_ref});
      #define #{itGet}(it) #{itGetElement}(it)
    $
  end

end # Maps


end # AutoC