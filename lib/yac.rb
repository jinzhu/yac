$:.unshift File.dirname(__FILE__)
%w(git fileutils yaml format).each {|f| require f}
module  Yac
  include Format
  extend self

  YACRC = File.join("#{ENV['HOME']}",".yacrc")

  FileUtils.cp(File.join(File.dirname(__FILE__), "..","resources","yacrc"), YACRC) unless File.exist?(YACRC)

  CONFIG = YAML.load_file(File.join(ENV['HOME'],".yacrc"))

  CONFIG["root"] ||= File.join(ENV['HOME'],".yac")

  @main_path, @pri_path = File.join(CONFIG["root"],"/main/"), File.join(CONFIG["root"],"/private/")
  @main_git = Git.new(@main_path)
  @pri_git = Git.new(@pri_path)

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
          Git.clone(CONFIG["#{name}"]['clone-from'],CONFIG['root'],name)
        else
          colorful("Initialize #{name} repository from scratch to #{CONFIG['root']}/#{name}","notice")
          prepare_dir(path)
          Git.init(path)
        end
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
    if new_name && confirm("You Are Renaming #{file} To #{new_name}")
      prepare_dir(new_name)
      @working_git.mv(file,new_name)
    end
  end

  protected
  def add_single(args)
    file = add_file(args)
    if file && confirm("You Are Adding #{file}")
      edit_text(file)
      @working_git.add(file)
    end
  end

  def add_file(args,suffix = ".ch")
    if args.include?('/') && args =~ /(@?)(?:(.*)\/)(.+)/ #choose directory
      prefix,path_name,file_name = $1,$2,$3
      path = prefix.empty? ? @pri_path : @main_path           #choose git path
      # Yes,you can use 'l/e' to choose 'linux/gentoo'
      all_path = %x{
        find #{path} -type d -iwholename '#{path}*#{path_name.gsub(/\//,'*/*')}*' -not -iwholename '*.git*'| sed 's/^.*\\/\\(private\\|main\\)\\//#{prefix}/'
      }.to_a.map(&:strip).concat([prefix+path_name]).uniq

      colorful("Which directory do you want to use:","notice")
      choosed_path = choose_one(all_path)
      return full_path(choosed_path + "/" + file_name + suffix) if choosed_path
    else
      return full_path(args+suffix)
    end
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
      @working_git.rm(file)
    end
  end

  def edit_single(args)
    file = search_name(args,"Edit")
    edit_file(file)
    @working_git.edit(file)
  end

  def search_name(args,msg = nil)
    path = (args =~ /^(@)/) ? [@main_path] : [@main_path , @pri_path]
    result = []
    path.each do |x|
      result.concat(`find "#{x}" -type f -iwholename '#{x}*#{args.gsub(/\//,'*/*').sub(/^@/,'').strip}*' -not -iwholename '*.git*'| sed 's/^.*\\/\\(private\\|main\\)\\//#{x=~/main/ ? '@':'' }/'`.to_a)
    end

    return result.empty? ? (colorful("Nothing Found About < #{args} >","warn")) :
      (colorful("The Results About < #{args} > To #{msg || "Operate"} :","notice");full_path(choose_one(result)))
  end

  def search_content(args)
    args.sub!(/^"(.*)"/,'\1') #Remove the " for input Regex
    result = `cd "#{@pri_path}" && grep -n -i -P '#{args}' -R *.ch 2>/dev/null`.to_a
    result.concat(`cd "#{@main_path}" && grep -n -i -P '#{args}' -R *.ch 2>/dev/null | sed 's/^/@/g'`.to_a)
    all_result = []
    result.each do |x|
      stuff = x.split(':',3)
      colorful(stuff[0],"filename",false)
      colorful(stuff[1],"line_number",false)
      format_section(empha(stuff[2],nil,/((#{args}))/i),true)
      all_result.concat(stuff[0].to_a)
    end
    all_result.uniq!
    loop do
      colorful("All files Contain #{args.strip},Choose one to show","notice")
      file = full_path(choose_one(all_result))
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
    return STDIN.gets.to_s =~ /n|q/i ? false : true
  end

  def choose_one(stuff)
    if stuff.size > 0
      stuff.each_index do |x|
        colorful("%2s" % (x+1).to_s,"line_number",false)
        printf "%-22s\t" % [stuff[x].rstrip]
        print "\n" if (x+1)%3 == 0
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
    return false if num =~ /q/i
    choosed_num = num.strip.empty? ? 1 : num.to_i
    (1..size).member?(choosed_num) ? (return choosed_num) : choose_range(size)
  end
end
