# frozen_string_literal: true


require 'autoc/module'


module AutoC

  OMP_H = Code.new interface: %{
    #ifdef _OPENMP
      #include <omp.h>
    #endif
  }

end