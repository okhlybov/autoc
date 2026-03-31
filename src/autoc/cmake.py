def CMake(module):
  cmake = f"{module.name}.cmake"
  sources = " ".join([f"${{CMAKE_CURRENT_SOURCE_DIR}}/{s.file_name}" for s in module.sources])
  contents = f"""
    set({module.name}_HEADER ${{CMAKE_CURRENT_SOURCE_DIR}}/{module.header.file_name})
    set({module.name}_SOURCES {sources})
    add_library({module.name}-auto OBJECT ${{{module.name}_SOURCES}})
    target_include_directories({module.name}-auto INTERFACE $<BUILD_INTERFACE:${{CMAKE_CURRENT_SOURCE_DIR}}>)
  """
  try:
    with open(cmake, "r") as f:
      if not f.read() == contents: raise Exception()
  except:
    with open(cmake, "w") as f:
      f.write(contents)


### On code generation vs. CMake

# https://here-be-braces.com/integrating-a-flexible-code-generator-into-cmake/
# https://blog.kangz.net/posts/2016/05/26/integrating-a-code-generator-with-cmake/


### On code packaging

# https://www.youtube.com/watch?v=sBP17HQAQjk
# https://www.youtube.com/watch?v=_5weX5mx8hc

# https://alexreinking.com/blog/how-to-use-cmake-without-the-agonizing-pain-part-1.html
# https://alexreinking.com/blog/how-to-use-cmake-without-the-agonizing-pain-part-2.html