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
    @all_result = []
    (help && exit) if args.empty?
    case args.first
    when "show" then show(args[1,args.size])
    when "name" then search(args[1,args.size],"name")
    when "content" then search(args[1,args.size],"content")
    when "update" then update(args[1,args.size])
    when /^(add|edit)$/ then edit(args[1,args.size])
    when /^(help|-h|yac|--help)$/ then help
    when /^(sh|shell)$/ then shell(args[1,args.size])
    when "rm" then rm(args[1,args.size])
    when "init" then init
    else show(args)
    end
    show_possible_result
  #rescue
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

  def search(args,type = "name")
    args.each {|x| search_single(x,type)}
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

  protected
  def rm_single(args)
    full_path(args)
    confirm("You are removing #@file_path")
    begin
      @working_git.remove(@file_path)
      @working_git.commit_all("#{args.sub(/^@/,"")}.ch removed")
    rescue Git::GitExecuteError
      FileUtils.rm_rf(@file_path)
    end
  end

  def edit_single(args)
    full_path(args)
    prepare_dir
    system("#{editor} #{@file_path}")
    @working_git.add
    @working_git.commit_all(" #{args.sub(/^@/,"")}.ch Updated")
  end

  def show_single(args)
    result = search_single(args)
    if result.size == 1
      colorful(result.first,"filename")
      format_file(result.first)
    else
      result.map do |x|
        if x =~ /\/#{args.sub(/^@/,"")}\.\w+/
          colorful(x,"filename")
          format_file(x)
        end
      end
    end
  end

  def search_single(args,type="name")
    if type =~ /name/
      search_name(args)
    else
      search_content(args)
    end
  end

  def search_name(args)
    if args =~ /^@/ && main = args.sub(/^@/,"")
      @private_result = []
      @main_result = @main_git.ls_files.keys.grep(/#{main}/)
    else
      @private_result = @pri_git.ls_files.keys.grep(/#{args}/)
        @main_result = @main_git.ls_files.keys.grep(/#{args}/)
    end
    @all_result << @main_result.collect {|x| "@" + x} << @private_result

    @private_result.map do |x|
      @main_result.delete(x)
    end
    return (@main_result.collect {|x| @main_path +x}).concat(@private_result.collect {|x| @pri_path +x})
  end

  def search_content(args)
    result = `cd #{@pri_path} && grep -n #{args} -R *.ch 2>/dev/null`
    result << `cd #{@main_path} && grep -n #{args} -R *.ch 2>/dev/null | sed 's/^/@/g'`
    result.each do |x|
      stuff = x.split(':',3)
      colorful(title_of_file(stuff[0]),"filename",false)
      print " "
      colorful(stuff[1],"line_number",false)
      print " "
      format_section(empha(stuff[2],nil,/((#{args}))/),true)
    end
  end

  def prepare_dir
    dirseparator = @file_path.rindex(File::Separator)+1
    FileUtils.mkdir_p(@file_path[0,dirseparator])
  end

  def full_path(args)
    if args =~ /^@/
      @file_path = @main_path + args.sub(/^@/,"") + ".ch"
      @working_git = @main_git
    else
      @file_path = @pri_path + args + ".ch"
      @working_git = @pri_git
    end
  end

  def confirm(*msg)
    colorful("#{msg.to_s} Are You Sure (Y/N):","notice",false)
    case STDIN.gets
    when /n/i
      exit
    when /y/i
      return true
    else
      colorful("Please Input A Valid String,","warn")
      confirm(msg)
    end
  end
end
