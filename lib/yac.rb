$:.unshift File.dirname(__FILE__)
%w(rubygems git fileutils yaml format).each {|f| require f}

module  Yac
  include Format
  extend self

  YACRC = File.join("#{ENV['HOME']}",".yacrc")

  FileUtils.cp(File.join(File.dirname(__FILE__), "..","resources","yacrc"), YACRC) unless File.exist?(YACRC)

  CONFIG = YAML.load_file(File.join(ENV['HOME'],".yacrc"))

  CONFIG["root"] ||= File.join(ENV['HOME'],".yac")

  @main_path, @pri_path = File.join(CONFIG["root"],"/main/"), File.join(CONFIG["root"],"/private/")
  @main_git = Git.open(@main_path) if File.exist?(@main_path)
  @pri_git = Git.open(@pri_path)if File.exist?(@pri_path)

  def new(args)
    init unless File.exist?(@main_path) && File.exist?(@pri_path)
    (help && exit) if args.empty?
    case args.first
    when "show" then show(args[1,args.size])
    when "search" then search(args[1,args.size])
    when "update" then update(args[1,args.size])
    when "push" then push(args[1,args.size])
    when "log" then log(args[1,args.size])
    when "add" then add(args[1,args.size])
    when "edit" then edit(args[1,args.size])
    when /^(help|-h|yac|--help)$/ then help
    when "sh" then shell(args[1,args.size])
    when "rm" then rm(args[1,args.size])
    when "mv" then rename(args[1,args.size])
    when /^version|-v$/ then
      load File.join(File.dirname(__FILE__), "..", "yac.gemspec");colorful("yac, version: " + VER,"notice")
    else show(args)
    end
  rescue
  end

  def init
    FileUtils.mkdir_p(CONFIG['root'])
    {"main" => @main_path,"private" => @pri_path}.each do |name,path|
      if File.exist?(path)
        colorful("#{name} repository has already initialized.","notice")
      else
        if CONFIG["#{name}"] && CONFIG["#{name}"]['clone-from']
          colorful("Initialize #{name} repository from #{CONFIG[name]['clone-from']} to #{CONFIG['root']}/#{name}","notice")
          Git.clone(CONFIG["#{name}"]['clone-from'], name, :path => CONFIG['root'])
        else
          colorful("Initialize #{name} repository from scratch to #{CONFIG['root']}/#{name}","notice")
          Git.init(path)
        end
        @main_git = Git.open(@main_path) if File.exist?(@main_path)
        @pri_git = Git.open(@pri_path)if File.exist?(@pri_path)
      end
    end
  end

  def show(args)
    args.each {|x| show_single(x)}
  end

  def search(args)
    args.each {|x| search_content(x)}
  end

  def update(args)
    git_command(args,'pull')
  rescue
    colorful("ERROR: can not update the repository,\n\n#{$!}","warn")
  end

  def push(args)
    git_command(args,'push')
  rescue
    colorful("Usage:\nyac push ( main | all )\n\nTry `yac -h` for more help\n\n#{$1}","warn")
  end

  def log(args)
    git_command(args,'log --color --date-order --reverse')
  end

  def git_command(env,command)
    case env.to_s
    when /main/ then git_path = [@main_path]
    when /all/ then git_path = [@main_path,@pri_path]
    else git_path = [@pri_path]
    end

    git_path.each do |x|
      colorful(x,'filename')
      colorful( `cd #{x} && git #{command}` ,"notice")
    end
  end

  def edit(args)
    args.each {|x| edit_single(x)}
  end

  def add(args)
    args.each {|x| add_single(x)}
  end

  def rm(args)
    args.each {|x| rm_single(x)}
  end

  def help
    format_file(File.dirname(__FILE__)+"/../README.rdoc")
  end

  def shell(args)
    case args.to_s
    when /main/
      colorful(" Welcome To The Main Yac Repository","notice")
      system "cd \"#{@main_path}\"; sh"
    else
      colorful(" Welcome To The Private Yac Repository","notice")
      system "cd \"#{@pri_path}\"; sh"
    end
  end

  def rename(args)
    (colorful("Usage:\nyac mv [orign_name] [new_name]\n\nTry `yac -h` for more help","warn");exit) unless args.size == 2
    file = search_name(args[0],"Rename")
    #You can use $ yac mv linux.ch linux/ to rename linux.ch to linux/linux.ch
    new_filename = args[1].sub(/\/$/,file.sub(/.*\/(.*)(\..*)/,'/\1')).sub(/^(@)?/,file =~ /^#{@main_path}/ ? "@":"")
    new_name = add_file(new_filename ,file.sub(/.*(\..*)/,'\1'))
    if confirm("You Are Renaming #{file} To #{new_name}")
      prepare_dir(new_name)
      `mv "#{file}" "#{new_name}"`
      @working_git.add
      @working_git.commit_all("#{clean_filename(file)} Renamed to #{clean_filename(new_name)}")
    end
  end

  protected
  def add_single(args)
    file = add_file(args)
    if confirm("You Are Adding #{file}")
      edit_text(file)
      @working_git.add
      @working_git.commit_all("#{clean_filename(file)} Added")
    end
  end

  def add_file(args,suffix = ".ch")
    if args.include?('/') && args =~ /(@?)(?:(.*)\/)(.+)/
      path = $1.empty? ? @pri_path : @main_path
      all_path = %x{
        find #{path} -type d -iwholename '#{path}*#{$2}*' -not -iwholename '*.git*'| sed 's/^.*\\(private\\|main\\)\\//#{$1}/'
      }.to_a
        colorful("Which directory do you want to use:","notice") if all_path.size >1
        choosed_path = choose_one(all_path.concat([$1+$2]).uniq)
        args = choosed_path + "/" + $3 if choosed_path
    end
    file = full_path(args+suffix)
  end

  def show_single(args)
    loop do
      file = search_name(args,"Show")
      file ? format_file(file) : break
    end
  end

  def rm_single(args)
    file = search_name(args,"Remove")
    if confirm("You Are Removing #{file}.")
      begin
        @working_git.remove(file)
        @working_git.commit_all("#{clean_filename(file)} Removed")
      rescue Git::GitExecuteError
        FileUtils.rm_rf(file)
      end
    end
  end

  def edit_single(args)
    file = search_name(args,"Edit")
    edit_file(file)
    @working_git.add
    @working_git.commit_all("#{clean_filename(file)} Updated")
  end

  def search_name(args,msg = nil)
    path = (args =~ /^(@)/) ? [@main_path] : [@main_path , @pri_path]
    result = []
    path.each do |x|
      result.concat(`find "#{x}" -type f -iwholename '#{x}*#{args.sub(/^@/,'').strip}*' -not -iwholename '*.git*'| sed 's/^.*\\(private\\|main\\)\\//#{x=~/main/ ? '@':'' }/'`.to_a)
    end

    return result.empty? ? (colorful("Nothing Found About < #{args} >","warn")) :
      (colorful("The Results About < #{args} > To #{msg || "Operate"} :","notice");full_path(choose_one(result)))
  end

  def search_content(args)
    args.sub!(/^"(.*)"/,'\1')
    result = `cd "#{@pri_path}" && grep -n -i -P '#{args}' -R *.ch 2>/dev/null`.to_a
    result.concat(`cd "#{@main_path}" && grep -n -i -P '#{args}' -R *.ch 2>/dev/null | sed 's/^/@/g'`.to_a)
    all_result = []
    result.each do |x|
      stuff = x.split(':',3)
      colorful(stuff[0],"filename",false)
      print " "
      colorful(stuff[1],"line_number",false)
      print " "
      format_section(empha(stuff[2],nil,/((#{args}))/i),true)
      all_result.concat(stuff[0].to_a)
    end
    all_result.uniq!
    loop do
      file = full_path(choose_one(all_result))
      colorful("All files Contain #{args.strip},Choose one to show","notice")
      file ? format_file(file) : break
    end
  end

  def full_path(args)
    return false unless args
    if args =~ /^@/
      @working_git = @main_git
      file = @main_path + args.sub(/^@/,"")
    else
      @working_git = @pri_git
      file = @pri_path + args
    end
    return file.strip
  end

  def confirm(*msg)
    colorful("#{msg.to_s}\nAre You Sure (Y/N) (q to quit):","notice",false)
    case STDIN.gets
    when /n|q/i
      return false
    when /y/i
      return true
    else
      colorful("Please Input A Valid String,","warn")
      confirm(msg)
    end
  end

  # Choose one file to operate
  def choose_one(stuff)
    if stuff.size > 0
      stuff.each_index do |x|
        colorful("%2s" % (x+1).to_s,"line_number",false)
        printf " %-20s \t" % [stuff[x].rstrip]
        print "\n" if (x+1)%4 == 0
      end
      printf "\n"
      num = choose_range(stuff.size)
      return stuff[num-1].to_s.strip #return the filename
    end
  rescue #Rescue for user input q to quit
  end

  #choose a valid number
  def choose_range(size)
    colorful("Please Input A Valid Number To Choose (1..#{size}) (q to quit): ","notice",false)
    num = STDIN.gets
    return if num =~ /q/i
    choosed_num = num.strip.empty? ? 1 : num.to_i
    (1..size).member?(choosed_num) ? (return choosed_num) : choose_range(size)
  end
end
