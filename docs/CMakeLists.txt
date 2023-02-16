project(docs)

cmake_minimum_required(VERSION 3.18)

find_package(Doxygen REQUIRED)

find_package(Ruby 3.0)

if(NOT Ruby_FOUND)
  message(STATUS "Attempting to locate Ruby executable manually")
  find_program(Ruby ruby REQUIRED)
endif()

add_custom_target(create COMMAND ${Ruby_EXECUTABLE} -I${CMAKE_CURRENT_LIST_DIR}/../lib -r autoc/scaffold -e docs)

doxygen_add_docs(generate autoc.h ALL WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
add_dependencies(generate create)