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
      FileUtils.mkdir_p(File.dirname(new))
      system("git mv #{orig} #{new}")
      self.commit("#{cleanup_name(orig)} Renamed to #{cleanup_name(new)}")
    end

    def add(file)
      if File.exist?(file)
        return system("rm #{file}") if File.zero?(file)
        system("git add '#{file}'")
        self.commit("#{cleanup_name(file)} Added")
      end
    end

    def edit(file)
      return rm(file) if File.zero?(file)
      system("git add '#{file}'")
      self.commit("#{cleanup_name(file)} Updated")
    end

    def rm(file)
      system("git rm -f '#{file}'")
      self.commit("#{cleanup_name(file)} Removed")
    end

    def commit(msg,*args)
      system("git commit #{args.to_s} -m '#{msg}' >/dev/null")
    end

    def cleanup_name(f)
      return f.sub(/^(.*)?\/(main|private)\/(.*)/,'\3').sub(/^@/,'')
    end
  end
end
