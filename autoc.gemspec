Gem::Specification.new do |g|
  g.name = "autoc"
  g.version = "0.7"
  g.author = "Oleg A. Khlybov"
  g.email = "fougas@mail.ru"
  g.homepage = "http://autoc.sourceforge.net/"
  g.summary = "A host of Ruby modules related to automatic C source code generation"
  g.files = Dir.glob ["lib/**/*", "manual/manual.pdf", "test/test.{c,rb}", "test/*_auto.[ch]", "README"]
  g.required_ruby_version = ">= 1.8"
  g.licenses = ["BSD"]
  g.description = <<-EOF
    AutoC is a collection of Ruby modules related to automatic C source code generation.
    CodeBuilder -- multi-file C module generator.
    DataStructBuilder -- generators of strongly-typed data containers similar to the C++'s standard generic containers.
  EOF
end