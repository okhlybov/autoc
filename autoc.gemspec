$: << "lib"; require "autoc"

Gem::Specification.new do |spec|
  spec.name = "autoc"
  spec.version = AutoC::VERSION
  spec.author = "Oleg A. Khlybov"
  spec.email = "fougas@mail.ru"
  spec.homepage = "http://autoc.sourceforge.net/"
  spec.summary = "A host of Ruby modules related to automatic C source code generation"
  spec.files = Dir.glob ["lib/**/*.rb", "doc/**/*", "test/{test*,value}.rb", "test/test_auto.[ch]", "README", "CHANGES", ".yardopts"]
  spec.required_ruby_version = ">= 1.8"
  spec.licenses = ["BSD-3-Clause"]
  spec.description = <<-EOF
    AutoC is a collection of Ruby modules related to automatic C source code generation:
    1) Multi-file C module generator.
    2) Generators for strongly-typed generic collections (Vector, List, Set etc.).
  EOF
end