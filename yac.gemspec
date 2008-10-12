GEM = "yac"
VER = "0.0.4"
DATE = %q{2008-10-11}
AUTHOR = "Jinzhu Zhang"
EMAIL = "wosmvp@gmail.com"
HOMEPAGE = "http://www.zhangjinzhu.com"
SUMMARY = "Yet Another Cheat"
 
Gem::Specification.new do |s|

  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=

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
 
  s.files = %w[README.rdoc README.cn yac.gemspec resources/yacrc bin/yac lib/yac.rb]

  s.has_rdoc = true
  s.rdoc_options = ["--quiet", "--title", "YAC => Yet Another Cheat", "--opname", "index.html", "--line-numbers", "--main", "README.rdoc", "--inline-source"]
  s.extra_rdoc_files = "README.rdoc"
 
  s.add_dependency("schacon-git", ">1.0.0")
end
