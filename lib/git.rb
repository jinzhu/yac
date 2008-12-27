class Git
  def initialize(path)
    @working_path = path
  end

  def self.clone(from,path)
   system("git clone #{from} #{path}")
  end

  def self.init(path)
   system("mkdir -p #{path}")
   system("cd #{path} && git init")
  end

  def mv(orig,new,with_commit = true)
    FileUtils.mkdir_p(File.dirname(file))
    system("cd '#@working_path' && git mv #{orig} #{new}")
    self.commit("#{clean_name(orig)} Renamed to #{clean_name(new)}") if with_commit
  end

  def add(file,with_commit = true)
    `cd '#@working_path' && git add '#{file}'`
    self.commit("#{clean_name(file)} Added") if with_commit
  end

  def edit(file,with_commit = true)
    `cd '#@working_path' && git add '#{file}'`
    self.commit("#{clean_name(file)} Updated") if with_commit
  end

  def rm(file,with_commit=true)
    `cd '#@working_path' && git rm -f '#{file}'`
    self.commit("#{clean_name(file)} Removed") if with_commit
  end

  def commit(msg,*args)
     `cd '#@working_path' && git commit #{args.to_s} -m '#{msg}'`
  end

  def clean_name(f)
    return f.sub(/^(.*)?\/(main|private)\/(.*)/,'\3').sub(/^@/,'')
  end
end
