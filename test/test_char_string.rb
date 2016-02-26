type_test(AutoC::String, :CharString) do
  
  test :createWithNULL, %~
    #{type} t;
    #{ctor}(&t, NULL);
    #{dtor}(&t);
  ~
  
  test :createWithEmptyChars, %~
    #{type} t;
    #{ctor}(&t, "");
    #{dtor}(&t);
  ~

end