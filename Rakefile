begin
  require 'rake/gempackagetask'
rescue LoadError
end
require 'rake/clean'

require 'rbconfig'
include Config

require "./lib/zeroconf/version"

PKG = "zeroconf"
ON_WINDOWS = RUBY_PLATFORM =~ /mswin32/i 
EXT_ROOT   = "ext"
EXT_DL     = "#{EXT_ROOT}/rdnssd.#{CONFIG['DLEXT']}"
EXT_SRC    = FileList.new("#{EXT_ROOT}/*.c","#{EXT_ROOT}/*.h")
CLEAN.include 'doc', 'coverage',
  FileList["ext/**/*.{so,bundle,#{CONFIG['DLEXT']},o,obj,pdb,lib,manifest,exp,def}"],
  FileList["ext/**/Makefile"]

desc "compile the native extension"
task :compile => EXT_DL

file EXT_DL => EXT_SRC do
  cd EXT_ROOT do
    ruby 'extconf.rb'
    sh 'make'
  end
end


zeroconf_gemspec = Gem::Specification.new do |s|
  s.name             = PKG
  s.version          = Zeroconf::VERSION
  s.platform         = Gem::Platform::RUBY
  s.has_rdoc         = true
  s.extra_rdoc_files = ["README.rdoc"]
  s.summary          = "Cross-platform zeroconf (bonjour™) library."
  s.description      = s.summary
  s.authors          = ["Lachie Cox"]
  s.email            = "lachiec@gmail.com"
  s.homepage         = "http://github.com/lachie/zeroconf"
  s.require_path     = "lib"
  s.files            = %w(README.rdoc Rakefile) + Dir.glob("{bin,lib,spec,originals,samples,test}/**/*")
end

Rake::GemPackageTask.new(zeroconf_gemspec) do |pkg|
  pkg.gem_spec = zeroconf_gemspec
end

namespace :gem do
  namespace :spec do
    desc "Update #{PKG}.gemspec"
    task :generate do
      File.open("#{PKG}.gemspec", "w") do |f|
        f.puts(zeroconf_gemspec.to_ruby)
      end
    end
    
    desc "test spec in github cleanroom"
    task :test => :generate do
      require 'rubygems/specification'
      data = File.read("#{PKG}.gemspec")
      spec = nil
      Thread.new { spec = eval("$SAFE = 3\n#{data}") }.join
      puts spec
    end
  end
end

task :install => [ :compile, :package ]