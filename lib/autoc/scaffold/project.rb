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
set(AUTOC_MODULE_SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/${PROJECT_NAME}.rb)

find_package(Ruby 3.0)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake)

include(AutoC)

add_autoc_module(
  ${AUTOC_MODULE_NAME}
  DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  MAIN_DEPENDENCY ${AUTOC_MODULE_SOURCE}
  COMMAND ${Ruby_EXECUTABLE} ${AUTOC_MODULE_SOURCE}
)

add_executable(${PROJECT_NAME} ${PROJECT_NAME}.c)
target_link_libraries(${PROJECT_NAME} ${AUTOC_MODULE_NAME})
END
end


###
def project_rb(project)
<<END
require 'autoc/module'
require 'autoc/cstring'

m = AutoC::Module.render(:_#{project}) do |m|
  m << AutoC::CString.new
end

require 'autoc/cmake'

AutoC::CMake.render(m)
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