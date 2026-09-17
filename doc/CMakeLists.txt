
cmake_minimum_required(VERSION 3.21)

project(autoc)

set(AUTOC_MODULE_NAME ${PROJECT_NAME})
set(AUTOC_MODULE_SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/${PROJECT_NAME}.py)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake)

find_package(Doxygen REQUIRED)

include(AutoC)

# The documentation module is regenerated from autoc.py and the generic container
# catalog whenever either changes
add_autoc_module(
  ${AUTOC_MODULE_NAME}
  DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  MAIN_DEPENDENCY ${AUTOC_MODULE_SOURCE}
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/catalog.py
  COMMAND ${Python_EXECUTABLE} ${AUTOC_MODULE_SOURCE} ${AUTOC_MODULE_NAME}
)

set(AUTOC_DOC_PAGES
  ${CMAKE_CURRENT_SOURCE_DIR}/mainpage.md
  ${CMAKE_CURRENT_SOURCE_DIR}/tutorial.md
  ${CMAKE_CURRENT_SOURCE_DIR}/design.md
  ${CMAKE_CURRENT_SOURCE_DIR}/containers.md
)

set(DOXYGEN_PROJECT_NAME "autoc")
set(DOXYGEN_PROJECT_BRIEF "C source code generation from Python")
set(DOXYGEN_USE_MDFILE_AS_MAINPAGE ${CMAKE_CURRENT_SOURCE_DIR}/mainpage.md)
set(DOXYGEN_OPTIMIZE_OUTPUT_FOR_C NO)
set(DOXYGEN_EXTRACT_ALL NO)
set(DOXYGEN_EXTRACT_STATIC YES)
# The manual documents groups and members; the raw C compounds (and the internal
# container components) are not its subject so their undoc warnings are silenced
set(DOXYGEN_WARN_IF_UNDOCUMENTED NO)
set(DOXYGEN_WARN_IF_INCOMPLETE_DOC NO)
set(DOXYGEN_FILE_PATTERNS "*.h" "*.md")
set(DOXYGEN_INPUT_ENCODING UTF-8)
set(DOXYGEN_GENERATE_TREEVIEW YES)
set(DOXYGEN_GENERATE_LATEX NO)
set(DOXYGEN_SHOW_FILES NO)

doxygen_add_docs(generate
  ${CMAKE_CURRENT_SOURCE_DIR}/autoc_auto.h
  ${AUTOC_DOC_PAGES}
  ALL
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
  COMMENT "Generating the autoc reference manual"
)

# The generated header must be up to date before Doxygen parses it
add_dependencies(generate autoc-generate)
