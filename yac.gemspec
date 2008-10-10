#!/usr/bin/env ruby

require 'rubygems'

Gem::Specification.new do |s|
  s.name = %q{yac}
  s.version = "0.0.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jinzhu Zhang"]
  s.date = %q{2008-10-10}
  s.homepage = %q{http://www.zhangjinzhu.com}
  s.default_executable = %q{yac}
  s.summary = %q{Yet Another Cheat}
  s.email = ["wosmvp@gmail.com"]
  s.executables = ["yac"]

  files = []
  files += Dir.glob('lib/*')
  files += Dir.glob('bin/*')
  files += Dir.glob('resources/*')
  files += %w[README.rdoc README.cn yac.gemspec]
  s.files       = files

  s.has_rdoc = true

  s.require_paths = ["lib"]
  s.extra_rdoc_files = "README.rdoc"
  s.rdoc_options = ["--main", "README.rdoc"]
  s.rubyforge_project = %q{yac}
  s.add_dependency("schacon-git", ">1.0.0")
end
