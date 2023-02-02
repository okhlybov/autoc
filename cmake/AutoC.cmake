function(add_autoc_module module)
  set(args DIRECTORY MAIN_DEPENDENCY)
  set(listArgs COMMAND)
  cmake_parse_arguments(key "${flags}" "${args}" "${listArgs}" ${ARGN})
  if(NOT key_DIRECTORY)
    set(key_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
  endif()
  if(NOT key_MAIN_DEPENDENCY)
    set(key_MAIN_DEPENDENCY ${key_DIRECTORY}/${module}.rb)
  endif()
  set(module_cmake ${key_DIRECTORY}/${module}.cmake)
  set(module_target ${module}-target)
  if(NOT EXISTS ${module_cmake})
    message(CHECK_START "Bootstrapping {" ${module} "}")
    execute_process(WORKING_DIRECTORY ${key_DIRECTORY} COMMAND ${key_COMMAND} VERBATIM)
  endif()
  include(${module_cmake})
  add_custom_command(
    OUTPUT ${module_cmake}
    MAIN_DEPENDENCY ${key_MAIN_DEPENDENCY}
    WORKING_DIRECTORY ${key_DIRECTORY}
    COMMAND ${key_COMMAND}
    VERBATIM
  )
  add_custom_target(${module_target} DEPENDS ${module_cmake})
  add_dependencies(${module} ${module_target})
endfunction()
