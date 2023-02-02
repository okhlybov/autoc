project(test LANGUAGES C)

cmake_minimum_required(VERSION 3.25)

find_program(Ruby_EXECUTABLE ruby REQUIRED)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/../cmake)

include(AutoC)

add_autoc_module(
  tests
  DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
  MAIN_DEPENDENCY ${CMAKE_CURRENT_LIST_DIR}/../lib/autoc/scaffold/tests.rb
  COMMAND ${Ruby_EXECUTABLE} -I../lib -r autoc/scaffold -e tests
)

add_executable(${PROJECT_NAME})
target_link_libraries(${PROJECT_NAME} tests)