GEM = "yac"
VER = "0.0.2"
AUTHOR = "Jinzhu Zhang"
EMAIL = "wosmvp@gmail.com"
HOMEPAGE = "http://www.zhangjinzhu.com"
SUMMARY = "Yet Another Cheat"
 
Gem::Specification.new do |s|
  s.name = GEM
  s.version = VER
  s.author = AUTHOR
  s.date = %q{2008-10-10}
  s.email = EMAIL
  s.homepage = HOMEPAGE
  s.summary = SUMMARY
  s.description = s.summary
 
  s.require_path = 'lib'
  s.autorequire = 'yac'
  s.executables = ["yac"]
 
  files = []
  files += Dir.glob('lib/*')
  files += Dir.glob('bin/*')
  files += Dir.glob('resources/*')
  files += %w[README.rdoc README.cn yac.gemspec]
  s.files       = files
 
  s.has_rdoc = true
  s.rdoc_options = ["--quiet", "--title", "YAC => Yet Another Cheat", "--opname", "index.html", "--line-numbers", "--main", "README.rdoc", "--inline-source"]
  s.extra_rdoc_files = ["README.rdoc", "README.cn"]
 
  s.add_dependency("schacon-git", ">1.0.0")
end
