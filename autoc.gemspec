$: << 'lib'

require 'autoc'

Gem::Specification.new do |s|
  s.required_ruby_version = '>= 3.0.0'
  s.name        = 'autoc'
  s.version     = AutoC::VERSION
  s.licenses    = ['BSD-2-Clause']
  s.summary     = 'C source code generation package'
  s.description = <<-EOF
    The package contains a functionality related to the C source code generation,
    including generation of the strongly-typed data structures (vectors, lists, maps etc.)
    in a manner provided by the C++'s STL library.
  EOF
  s.authors     = ['Oleg A. Khlybov']
  s.email       = 'fougas@mail.ru'
  s.homepage    = 'https://github.com/okhlybov/autoc'
  s.metadata    = {
    'source_code_uri' => 'https://github.com/okhlybov/autoc'
  }
  s.files       = Dir['lib/**/*.rb'] + Dir['cmake/*']
  s.extra_rdoc_files = ['README.md', 'CHANGES.md']
end