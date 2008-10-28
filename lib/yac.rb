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
    unless File.exist?(@main_path) && File.exist?(@pri_path)
      return unless init
    end
    (help && exit) if args.empty?
    case args.first
    when "show" then show(args[1,args.size])
    when "search" then search(args[1,args.size])
    when "update" then update(args[1,args.size])
    when "add" then add(args[1,args.size])
    when "edit" then edit(args[1,args.size])
    when /^(help|-h|yac|--help)$/ then help
    when /^(sh|shell)$/ then shell(args[1,args.size])
    when "rm" then rm(args[1,args.size])
    when "mv" then rename(args[1,args.size])
    when "init" then init
    else show(args)
    end
  rescue
  end

  def init
    FileUtils.mkdir_p(CONFIG['root'])
    {"main" => @main_path,"private" => @pri_path}.each do |name,path|
      unless File.exist?(path)
        if CONFIG["#{name}"] && CONFIG["#{name}"]['clone-from']
          puts "Initialize #{name} repository from #{CONFIG[name]['clone-from']} to #{CONFIG['root']}/#{name}"
          Git.clone(CONFIG["#{name}"]['clone-from'], name, :path => CONFIG['root'])
        else
          puts "Initialize #{name} repository from scratch to #{CONFIG['root']}/#{name}"
          git = Git.init(path)
          git.add
          git.commit_all("init #{name} repository")
        end
        puts "#{name} repository initialized."
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
    unless args.empty?
      @pri_git.pull if args.to_s =~ /pri/
        @main_git.pull if args.to_s =~ /main/
    else
      @main_git.pull && @pri_git.pull
    end
  rescue
    puts "ERROR: can not update the repository,\n #{$!}"
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
      colorful(" Welcome To The Main Yac Repository","head1")
      system "cd #{@main_path}; sh"
    else
      colorful(" Welcome To The Private Yac Repository","head1")
      system "cd #{@pri_path}; sh"
    end
  end

  def rename(args)
    (colorful("Usage:\nyac mv [orign_name] [new_name]\n\nTry `yac -h` for more help","warn");exit) unless args.size == 2
    file = search_name(args[0],"Rename")
    new_name = file.sub(/^((?:.*)?(?:main|private)\/)(.*)(\..*)/,'\1'+args[1]+'\3')
    confirm("You Are Renaming #{file} To #{new_name}")
    if `mv #{file} #{new_name}`
      @working_git.add
      @working_git.commit_all("#{clean_filename(file)} Renamed to #{clean_filename(new_name)}")
    end
  end

  protected
  def add_single(args)
    if args.include?('/') && args =~ /(@?)(?:(.*)\/)(.+)/
      path = $1.empty? ? @pri_path : @main_path
      all_path = `find #{path} -type d -iwholename '*#{$2}*' -not -iwholename '*.git*'| sed 's/^#{regex_protect(path)}/#{$1}/'`.to_a
      choosed_path = choose_one(all_path)
      args = choosed_path + "/" + $3 if choosed_path
    end
    file = full_path(args+".ch")
    confirm("You Are Adding #{file}")
    edit_text(file)
    @working_git.add
    @working_git.commit_all("#{clean_filename(file)} Added")
  end

  def show_single(args)
    file = search_name(args,"Show")
    format_file(file)
  end

  def rm_single(args)
    file = search_name(args,"Remove")
    confirm("You are removing #{file}.")
    begin
      @working_git.remove(file)
      @working_git.commit_all("#{clean_filename(file)} was removed")
    rescue Git::GitExecuteError
      FileUtils.rm_rf(file)
    end
  end

  def edit_single(args)
    file = search_name(args,"Edit")
    edit_file(file)
    @working_git.add
    @working_git.commit_all("#{clean_filename(file)} Updated")
  end

  def search_name(args,msg = nil)
    if args =~ /^@/ && main = args.sub(/^@/,"")
      @private_result = []
      @main_result = %x{
        find #{@main_path} -type f -iwholename "*#{main}*" -not -iwholename "*.git*"| sed 's/^#{regex_protect(@main_path)}/@/'
      }.to_a
    else
      @private_result = %x{
        find #{@pri_path} -type f -iwholename "*#{args}*" -not -iwholename "*.git*"| sed 's/^#{regex_protect(@pri_path)}//'
      }.to_a

      @main_result = %x{
        find #{@main_path} -type f -iwholename "*#{args}*"  -not -iwholename "*.git*"| sed 's/^#{regex_protect(@main_path)}/@/'
      }.to_a
    end
    result = @main_result.concat(@private_result)
    return result.empty? ? (colorful("Nothing Found About < #{args} >","warn")) :
      (colorful("The Results About < #{args} > To #{msg || "Operate"} :","notice");full_path(choose_one(result)))
  end

  def search_content(args)
    result = `cd #{@pri_path} && grep -n #{args} -R *.ch 2>/dev/null`
    result << `cd #{@main_path} && grep -n #{args} -R *.ch 2>/dev/null | sed 's/^/@/g'`
    result.each do |x|
      stuff = x.split(':',3)
      colorful(clean_filename(stuff[0]),"filename",false)
      print " "
      colorful(stuff[1],"line_number",false)
      print " "
      format_section(empha(stuff[2],nil,/((#{args}))/),true)
    end
  end

  def full_path(args)
    if args =~ /^@/
      file = @main_path + args.sub(/^@/,"")
      @working_git = @main_git
    else
      file = @pri_path + args
      @working_git = @pri_git
    end
    return file
  end

  # To confirm Operate OR Not
  def confirm(*msg)
    colorful("#{msg.to_s}\nAre You Sure (Y/N) (Q to quit):","notice",false)
    case STDIN.gets
    when /n|q/i
      exit
    when /y/i
      return true
    else
      colorful("Please Input A Valid String,","warn")
      confirm(msg)
    end
  end

  # Choose one file to operate
  def choose_one(stuff)
    if stuff.size == 1
      return stuff[0]
    elsif stuff.size > 1
      stuff.each_index do |x|
        colorful("%2s" % (x+1).to_s,"line_number",false)
        printf " %-20s \t" % [stuff[x].rstrip]
        print "\n" if (x+1)%4 == 0
      end
      printf "\n"
      num = choose_range(stuff.size)
      return stuff[num-1].to_s.strip
    end
  rescue #Rescue for user input q to quit
  end

  #choose a valid range
  def choose_range(size)
    colorful("Please Input A Valid Number To Choose (1..#{size}) (Q to quit): ","notice",false)
    num = STDIN.gets
    return if num =~ /q/i
    (1..size).member?(num.to_i) ? (return num.to_i) : choose_range(size)
  end

  def regex_protect(args)
    args.gsub(/\//,'\/')
  end
end
