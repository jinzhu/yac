GEM = "yac"
VER = "1.0.2"
DATE = %q{2008-10-28}
AUTHOR = "Jinzhu Zhang"
EMAIL = "wosmvp@gmail.com"
HOMEPAGE = "http://www.zhangjinzhu.com"
SUMMARY = "Yet Another Cheat: sexy command line tool for cheat sheet"
 
Gem::Specification.new do |s|

  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=

  s.rubyforge_project = 'yac'
  s.name = GEM
  s.version = VER
  s.author = AUTHOR
  s.date = DATE
  s.email = EMAIL
  s.homepage = HOMEPAGE
  s.summary = SUMMARY
  s.description = s.summary
 
  s.require_path = 'lib'
  s.autorequire = 'yac'
  s.executables = ["yac"]
 
  s.files = %w[README.rdoc yac.gemspec resources/yacrc bin/yac lib/yac.rb lib/format.rb]

  #s.has_rdoc = true
  s.rdoc_options = ["--quiet", "--title", "YAC => Yet Another Cheat", "--opname", "index.html", "--line-numbers", "--main", "README.rdoc", "--inline-source"]
  s.extra_rdoc_files = "README.rdoc"
 
  s.add_dependency("schacon-git", ">1.0.0")
end
