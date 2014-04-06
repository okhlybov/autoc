Gem::Specification.new do |spec|
  spec.name = "autoc"
  spec.version = "0.9"
  spec.author = "Oleg A. Khlybov"
  spec.email = "fougas@mail.ru"
  spec.homepage = "http://autoc.sourceforge.net/"
  spec.summary = "A host of Ruby modules related to automatic C source code generation"
  spec.files = Dir.glob ["lib/**/*.rb", "manual/manual.pdf", "test/test.{c,rb}", "test/*_auto.[ch]", "README"]
  spec.required_ruby_version = ">= 1.8"
  spec.licenses = ["BSD"]
  spec.description = <<-EOF
    AutoC is a collection of Ruby modules related to automatic C source code generation.
    * CodeBuilder -- multi-file C module generator.
    * DataStructBuilder -- generators of strongly-typed data containers similar to the C++'s standard generic containers.
  EOF
end