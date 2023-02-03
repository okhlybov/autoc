###
def project_c(project)
<<END
#include "_#{project}_auto.h"

#include <stdio.h>

int main(int argc, char **argv) {
  CString msg;
  CStringCreateFormat(&msg, "Hello %s!\\n", "#{project}");
  printf(msg);
  CStringDestroy(&msg);
  return 0;
}
END
end


###
def cmakelists_txt(project)
<<END
project(#{project})

cmake_minimum_required(VERSION 3.0)

set(AUTOC_MODULE_NAME _${PROJECT_NAME})

find_program(Ruby_EXECUTABLE ruby REQUIRED)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake)

include(AutoC)

add_autoc_module(
  ${AUTOC_MODULE_NAME}
  DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
  MAIN_DEPENDENCY ${CMAKE_CURRENT_LIST_DIR}/${PROJECT_NAME}.rb
  COMMAND ${Ruby_EXECUTABLE} ${CMAKE_CURRENT_LIST_DIR}/${PROJECT_NAME}.rb
)

add_executable(${PROJECT_NAME} ${PROJECT_NAME}.c)
target_link_libraries(${PROJECT_NAME} ${AUTOC_MODULE_NAME})
END
end


###
def project_rb(project)
<<END
require 'autoc/cmake'
require 'autoc/module'
require 'autoc/cstring'

AutoC::CMake.render(AutoC::Module.render(:_#{project}) do |m|
  m << AutoC::CString.new
end)
END
end


if ARGV.size < 1
  $stderr << "usage: ruby -r autoc/scaffold -e project project_name\n"
  exit 1
end

project = ARGV[0]

require 'fileutils'
FileUtils.copy_entry(File.dirname(__FILE__)+'/../../../cmake', 'cmake')

File.write('CMakeLists.txt', cmakelists_txt(project))
File.write("#{project}.rb", project_rb(project))
File.write("#{project}.c", project_c(project))