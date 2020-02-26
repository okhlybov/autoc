Gem::Specification.new do |spec|
  spec.name = 'autoc'
  spec.version = '2.0.0'
  spec.author = 'Oleg A. Khlybov'
  spec.email = 'fougas@mail.ru'
  spec.homepage = 'https://github.com/okhlybov/autoc'
  spec.summary = 'A host of Ruby modules related to automatic C source code generation'
  spec.files = Dir.glob ['lib/**/*.rb', 'README', 'CHANGES', ''.yardopts']
  spec.required_ruby_version = '>= 2.0'
  spec.licenses = ['BSD-3-Clause']
  spec.description = <<-EOF
    AutoC is a collection of Ruby modules related to automatic C source code generation:
    1) Multi-file C module generator.
    2) Generators for typed generic collections (Vector, List, Set etc.).
  EOF
end