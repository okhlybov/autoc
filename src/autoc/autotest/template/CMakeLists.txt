cmake_minimum_required(VERSION 3.21)

project(@module@)

set(AUTOC ON) # Regenerate unconditionally

set(AUTOC_MODULE_NAME @module@)
set(AUTOC_MODULE_SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/${AUTOC_MODULE_NAME}.py)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake)

include(AutoC)

add_autoc_module(
  ${AUTOC_MODULE_NAME}
  DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  MAIN_DEPENDENCY ${AUTOC_MODULE_SOURCE}
  COMMAND ${Python_EXECUTABLE} ${AUTOC_MODULE_SOURCE} ${AUTOC_MODULE_NAME}
)

add_executable(${PROJECT_NAME})
target_link_libraries(${PROJECT_NAME} ${AUTOC_MODULE_NAME}-autoc)
