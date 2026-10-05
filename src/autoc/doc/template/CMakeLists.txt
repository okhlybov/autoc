cmake_minimum_required(VERSION 3.21)

project(@project@)

set(AUTOC_MODULE_NAME ${PROJECT_NAME})
set(AUTOC_MODULE_SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/${PROJECT_NAME}.py)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake)

find_package(Doxygen REQUIRED)

include(AutoC)

# The documentation module is regenerated from @project@.py whenever definitions change
add_autoc_module(
  ${AUTOC_MODULE_NAME}
  DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  MAIN_DEPENDENCY ${AUTOC_MODULE_SOURCE}
  COMMAND ${Python_EXECUTABLE} ${AUTOC_MODULE_SOURCE} ${AUTOC_MODULE_NAME}
)

include(${CMAKE_CURRENT_SOURCE_DIR}/${AUTOC_MODULE_NAME}.cmake)

set(PROJECT_VERSION "${${AUTOC_MODULE_NAME}_VERSION}")
set(AUTOC_VERSION "${${AUTOC_MODULE_NAME}_VERSION}")

# Filter documentation pages on consumption for @@ variable substitution
set(DOC_FILTERED_PAGES "")
foreach(page IN LISTS ${AUTOC_MODULE_NAME}_DOC_PAGES)
  get_filename_component(page_name "${page}" NAME)
  set(filtered_page "${CMAKE_CURRENT_BINARY_DIR}/${page_name}")
  configure_file("${page}" "${filtered_page}" @ONLY)
  list(APPEND DOC_FILTERED_PAGES "${filtered_page}")
endforeach()

get_filename_component(mainpage_name "${${AUTOC_MODULE_NAME}_DOC_MAINPAGE}" NAME)
set(DOC_FILTERED_MAINPAGE "${CMAKE_CURRENT_BINARY_DIR}/${mainpage_name}")

set(DOXYGEN_PROJECT_NAME "autoc")
set(DOXYGEN_PROJECT_NUMBER "${${AUTOC_MODULE_NAME}_VERSION}")
set(DOXYGEN_PROJECT_BRIEF "C source code generation from Python")
set(DOXYGEN_USE_MDFILE_AS_MAINPAGE "${DOC_FILTERED_MAINPAGE}")
set(DOXYGEN_OPTIMIZE_OUTPUT_FOR_C YES)
set(DOXYGEN_EXTRACT_ALL YES)
set(DOXYGEN_EXTRACT_STATIC YES)
set(DOXYGEN_SORT_MEMBER_DOCS YES)
set(DOXYGEN_SORT_BRIEF_DOCS YES)
# The manual documents groups and members; the raw C compounds (and the internal
# container components) are not its subject so their undoc warnings are silenced
set(DOXYGEN_WARN_IF_UNDOCUMENTED NO)
set(DOXYGEN_WARN_IF_INCOMPLETE_DOC NO)
set(DOXYGEN_FILE_PATTERNS "*.h" "*.md")
set(DOXYGEN_INPUT_ENCODING UTF-8)
set(DOXYGEN_GENERATE_TREEVIEW YES)
#set(DOXYGEN_GENERATE_LATEX YES)
set(DOXYGEN_GENERATE_PDF YES)
set(DOXYGEN_SHOW_FILES NO)

doxygen_add_docs(generate
  ${CMAKE_CURRENT_SOURCE_DIR}/@module@_auto.h
  ${DOC_FILTERED_PAGES}
  ALL
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
  COMMENT "Generating the autoc reference manual"
)

add_custom_target(@project@ DEPENDS generate)
add_custom_target(autoc-generate DEPENDS generate)
