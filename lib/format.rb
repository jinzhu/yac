class Symbol
  def to_proc
    Proc.new { |*args| args.shift.__send__(self, *args) }
  end
end

module Format
  Pdf_Error = "Please Modify ~/.yacrc To Provide A Valid Command To Operate PDF Document"
  Image_Error = "Please Modify ~/.yacrc To Provide A Valid Command To Operate Image Document"
  Doc_Error = "Please Modify ~/.yacrc To Provide A Valid Command To Operate Text Document"

  def format_file(file)
    @level = 0
    colorful(file,"filename") if file
    case `file "#{file}" 2>/dev/null`
    when / PDF document/
      puts Pdf_Error unless system("#{Yac::CONFIG["pdf_command"]||'evince'} '#{file}' 2>/dev/null")
    when /( image )|(\.svg)/
      puts Image_Error unless system("#{Yac::CONFIG["image_command"]||'eog'} '#{file}' 2>/dev/null")
    #TODO add office support
    else
      File.new(file).each do |x|
        format_section(x)
      end
    end
  rescue
  end

  def format_section(section,empha_regexp = false)
    if section =~ /^(=+)\s+(.*)/
      level,stuff = $1.size,$2
      # Highlight the keyword when searching
      stuff = empha(stuff,"head#{level}",empha_regexp) if empha_regexp
      colorful("\s"*(level-1) + stuff,"head#{level}")
    else
      section = empha(section,"text",empha_regexp) if empha_regexp
      colorful(section)
    end
  end

  def edit_file(file)
    case `file "#{file}" 2>/dev/null`
    when / PDF /
      puts Pdf_Error unless system("#{Yac::CONFIG["pdf_edit_command"]||'ooffice'} '#{file}' 2>/dev/null")
    when /( image )|(\.svg)/
      puts Image_Error unless system("#{Yac::CONFIG["image_edit_command"]||'gimp'} '#{file}' 2>/dev/null")
    #TODO and Edit
    else
      edit_text(file)
    end
  end

  def edit_text(file)
    prepare_dir(file)
    puts Doc_Error unless system("#{Yac::CONFIG["editor"] || ENV['EDITOR'] ||'vim'} '#{file}' 2>/dev/null")
  end

  def colorful(stuff,level="text",line_break = true)
    stuff = empha(stuff,level)
    print "\e[%sm%s\e[0m " % [Yac::CONFIG[level],stuff.rstrip]
    print "\n" if line_break
  end

  def empha(stuff,level="text",empha_regexp=/(@(.*)@)/)
    stuff.to_s.scan(empha_regexp) do |x|
      return stuff.gsub(x[0],"\e[0m\e[#{Yac::CONFIG["empha"]}m%s\e[0m\e[%sm" % [x[1],Yac::CONFIG[level]])
    end
  end

  def prepare_dir(file)
    FileUtils.mkdir_p(File.dirname(file))
  end
end
