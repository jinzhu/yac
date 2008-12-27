class Git
  class << self
    def clone(from,path)
      system("git clone #{from} #{path}")
    end

    def init(path)
      system("mkdir -p #{path}")
      system("cd #{path} && git init")
    end

    def mv(orig,new)
      FileUtils.mkdir_p(File.dirname(file))
      system("git mv #{orig} #{new}")
      self.commit("#{cleanup_name(orig)} Renamed to #{cleanup_name(new)}")
    end

    def add(file)
      `git add '#{file}'`
      self.commit("#{cleanup_name(file)} Added")
    end

    def edit(file)
      `git add '#{file}'`
      self.commit("#{cleanup_name(file)} Updated")
    end

    def rm(file)
      `git rm -f '#{file}'`
      self.commit("#{cleanup_name(file)} Removed")
    end

    def commit(msg,*args)
      `git commit #{args.to_s} -m '#{msg}'`
    end

    def cleanup_name(f)
      return f.sub(/^(.*)?\/(main|private)\/(.*)/,'\3').sub(/^@/,'')
    end
  end
end
