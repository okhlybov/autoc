# frozen_string_literal: true


require 'autoc/module'


module AutoC


# CMake package renderer for the AutoC module
class CMake

  attr_reader :module

  def file_name = @file_name ||= "#{self.module.name}-config.cmake"

  def initialize(m)
    @module = m
  end

  def render
    source_list = self.module.sources.collect { |s| "${CMAKE_CURRENT_LIST_DIR}/#{s.file_name}" }
    File.open(file_name, 'wt') do |stream|
      stream << %{
        add_library(#{self.module.name} OBJECT #{source_list.join(' ')})
        target_include_directories(#{self.module.name} INTERFACE $<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}>)
      }
    end
  end
  
  def self.render(m) = self.new(m).render

end # CMake


end