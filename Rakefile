require 'zip/zip'


Package = 'autoc'
Version = '0.2'


task :default => [:dist]


task :gen_doc do
  cd('lib')
  begin
    sh('rdoc', '--main=autoc.rb', '--op=../doc')
  ensure
    cd('..')
  end
end


task :gen_test do
  cd('test')
  begin
    ruby('-I../lib', 'test.rb')
  ensure
    cd('..')
  end
end


task :dist => [:gen_doc, :gen_test] do
  package = "#{Package}-#{Version}.zip"
  files = FileList.new ['lib/**/*', 'doc/**/*', 'test/test.{c,rb}', 'test/*_auto.[ch]', 'etc/**/*', 'Rakefile', 'README']
  begin
    FileUtils.rm_rf(package)
  rescue Errno::ENOENT
  end
  Zip::ZipFile.open(package, Zip::ZipFile::CREATE) do |zip|
    files.each do |file|
      zip.add(file, file)
    end
  end
end