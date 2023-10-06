
      set(tests_HEADER ${CMAKE_CURRENT_SOURCE_DIR}/tests_auto.h)
      set(tests_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/tests_auto1.c ${CMAKE_CURRENT_SOURCE_DIR}/tests_auto2.c ${CMAKE_CURRENT_SOURCE_DIR}/tests_auto3.c ${CMAKE_CURRENT_SOURCE_DIR}/tests_auto4.c)
      add_library(tests OBJECT ${tests_SOURCES})
      target_include_directories(tests INTERFACE $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
    