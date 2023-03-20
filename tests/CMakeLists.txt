cmake_minimum_required(VERSION 3.15)

project(test LANGUAGES C)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/../cmake)

include(AutoC)

file(GLOB AUTOS *_auto*.[ch])

add_autoc_module(
  tests
  DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
  MAIN_DEPENDENCY ${CMAKE_CURRENT_LIST_DIR}/../lib/autoc/scaffold/tests.rb
  COMMAND ${Ruby_EXECUTABLE} -I../lib -r autoc/scaffold -e tests && astyle -n ${AUTOS}
)

add_executable(${PROJECT_NAME})
target_link_libraries(${PROJECT_NAME} tests)
