# frozen_string_literal: true


require 'digest'
require 'autoc/module'


module AutoC


# CMake package renderer for the AutoC module
class CMake

  attr_reader :module

  def file_name = "#{self.module.name}.cmake"

  def initialize(m) = @module = m

  def render
    sources = self.module.sources.collect { |s| "${CMAKE_CURRENT_SOURCE_DIR}/#{s.file_name}" } .join(' ')
    stream = %{
      set(#{self.module.name}_HEADER ${CMAKE_CURRENT_SOURCE_DIR}/#{self.module.header.file_name})
      set(#{self.module.name}_SOURCES #{sources})
      add_library(#{self.module.name} OBJECT ${#{self.module.name}_SOURCES})
      target_include_directories(#{self.module.name} INTERFACE $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
    }
    unless Digest::MD5.digest(stream) == (Digest::MD5.digest(File.read(file_name)) rescue nil)
      File.write(file_name, stream)
    end
  end
  
  def self.render(m) = self.new(m).render

end # CMake


end


### On code generation vs. CMake

# https://here-be-braces.com/integrating-a-flexible-code-generator-into-cmake/
# https://blog.kangz.net/posts/2016/05/26/integrating-a-code-generator-with-cmake/


### On code packaging

# https://www.youtube.com/watch?v=sBP17HQAQjk
# https://www.youtube.com/watch?v=_5weX5mx8hc

# https://alexreinking.com/blog/how-to-use-cmake-without-the-agonizing-pain-part-1.html
# https://alexreinking.com/blog/how-to-use-cmake-without-the-agonizing-pain-part-1.html