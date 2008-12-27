$LOAD_PATH << File.dirname(__FILE__)
%w(git fileutils yaml format).each {|f| require f}

module  Yac
  include Format
  extend self

  VERSION = '1.3.2'

  YACRC = File.join("#{ENV['HOME']}",".yacrc")
  CONFIG = YAML.load_file( File.exist?(YACRC) ? YACRC :
              File.join(File.dirname(__FILE__), "..","resources","yacrc"))

  CONFIG["root"] ||= File.join(ENV['HOME'],".yac")

  @main_path = File.join(CONFIG["root"],"/main/")
  @pri_path  = File.join(CONFIG["root"],"/private/")
  @main_git  = Git.new(@main_path)
  @pri_git   = Git.new(@pri_path)

  def new(args)
    (help && exit) if args.empty?
    operate,target = args.first,args[1,args.size].join(' ')
    case operate
    when "-i" then init
    when "-S" then search(target)
    when "-u" then update(target)
    when "-p" then push(target)
    when "-l" then log(target)
    when "-a" then add(target)
    when "-e" then edit(target)
    when /^(help|-h|yac|--help)$/ then help
    when "-s" then shell(target)
    when "-r" then rm(target)
    when "-m" then mv(args[1,args.size])
    when "-v" then colorful("Yac Version: #{Yac::VERSION}",'notice')
    else show(operate + ' ' + target)
    end
  end

  def init
    {"main" => @main_path,"private" => @pri_path}.each do |name,path|
      if File.exist?(path)
        colorful("#{name} repository has already initialized.","notice")
      elsif CONFIG["#{name}"] && CONFIG["#{name}"]['clone-from']
        colorful("Initialize #{name} repository from #{CONFIG[name]['clone-from']}","notice")
        Git.clone(CONFIG["#{name}"]['clone-from'],path)
      end
    end
  end

  def show(args)
    loop do
      file = search_name(args,"Show")
      file ? format_file(file) : break
    end
  end

  def search(args)
    search_content(args)
  end

  def add(args)
    file = add_file(args,'.yac')
    if file && confirm("You Are Adding #{file}")
      edit_text(file)
      @working_git.add(file)
    end
  end

  def edit(args)
    file = search_name(args,"Edit")
    if file
      edit_file(file)
      @working_git.edit(file)
    end
  end

  def rm(args)
    file = search_name(args,"Remove")
    if file && confirm("You Are Removing #{file}.")
      @working_git.rm(file)
    end
  end

  def help
    format_file(File.dirname(__FILE__)+"/../README.rdoc")
  end

  def shell(args)
    if args.to_s =~ /main/
      colorful(" Welcome To The Main Yac Repository","notice")
      system("cd '#{@main_path}'; sh")
    else
      colorful(" Welcome To The Private Yac Repository","notice")
      system("cd '#{@pri_path}'; sh")
    end
  end

  def mv(args)
    (colorful("Usage:\nyac mv [orign_name] [new_name]","warn");exit) unless args.size == 2
    file = search_name(args[0],"Rename")

    # You can use $ yac mv linux.ch linux/ to rename linux.ch to linux/linux.ch
    new_filename = args[1] =~ /\/$/ ? args[1] : args[1] + file.match(/[^\/]$/).to_s
    new_filename = '@' + new_filename if file =~ /^#{@main_path}/
    new_name = add_file(new_filename)

    if new_name && confirm("You Are Renaming #{file} To #{new_name}")
      @working_git.mv(file,new_name)
    end
  end

  protected
  def add_file(args,*suffix)
    suffix = suffix ? suffix.to_s : ''
    if args.include?('/') && args =~ /(@?)(?:(.*)\/)(.+)/       #choose directory
      prefix,path_name,file_name = $1,$2,$3
      path = prefix.empty? ? @pri_path : @main_path             #choose git path
      # Use 'l/e' to choose 'linux/gentoo'
      all_path = %x{
        find -L #{path} -type d -iwholename '#{path}*#{path_name.gsub(/\//,'*/*')}*' -not -iwholename '*\/.git\/*' | sed 's/^.*\\/\\(private\\|main\\)\\//#{prefix}/'
      }.to_a.map(&:strip).concat([prefix+path_name]).uniq

      colorful("Which directory do you want to use:","notice")
      choosed_path = choose_one(all_path)
      return choosed_path ?  full_path(choosed_path + "/" + file_name + suffix) : false
    else
      return full_path(args + suffix)
    end
  end

  #
  # Git
  #

  def update(args)
    git_command(args,'pull')
  end

  def push(args)
    git_command(args,'push')
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
      system("cd #{x} && git #{command}")
    end
  end

  def search_name(args,msg = nil)
    path = (args =~ /^(@)/) ? [@main_path] : [@main_path , @pri_path]
    result = []
    path.each do |x|
      result.concat(`find "#{x}" -type f -iwholename '#{x}*#{args.gsub(/\//,'*/*').sub(/^@/,'').strip}*' -not -iwholename '*\/.git\/*'| sed 's/^.*\\/\\(private\\|main\\)\\//#{x=~/main/ ? '@':'' }/'`.to_a)
    end

    if result.empty?
      colorful("Nothing Found About < #{args} >","warn")
      return false
    else
      colorful("The Results About < #{args} > To #{msg} :","notice")
      return full_path(choose_one(result))
    end
  end

  def search_content(args)
    result = `find "#{@pri_path}" -iname '*.ch' -not -iwholename '*\/.git\/*' -exec grep -HniP '#{args}' '{}' \\;`.to_a
    result.concat(`find "#{@main_path}" -iname '*.ch' -not -iwholename '*\/.git\/*' -exec grep -HniP '#{args}' '{}' \\; | sed 's/^/@/g'`.to_a)
    all_result = []
    result.each do |x|
      stuff = x.split(':',3)
      colorful(File.basename(stuff[0]).sub(/\..*/,''),"filename",false)
      colorful(stuff[1],"line_number",false)
      format_section(stuff[2],/((#{args}))/i)
      all_result << stuff[0].sub(/(@?).*\/(?:main|private)\/(.*)/,'\1'+'\2')
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
