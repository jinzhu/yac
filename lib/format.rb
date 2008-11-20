class Symbol
  def to_proc
    Proc.new { |*args| args.shift.__send__(self, *args) }
  end
end

module Format
  Pdf_Error = "Please Modify ~/.yacrc To Provide A Valid Command To Operate PDF Document"
  Image_Error = "Please Modify ~/.yacrc To Provide A Valid Command To Operate Image Document"
  Office_Error = "Please Modify ~/.yacrc To Provide A Valid Command To Operate Office Document"
  Doc_Error = "Please Modify ~/.yacrc To Provide A Valid Command To Operate Text Document"

  def format_file(file)
    colorful(file,"filename") if file
    case `file "#{file}" 2>/dev/null`
    when / PDF document/
      colorful(Pdf_Error,'warn') unless system("#{Yac::CONFIG["pdf_command"]||'evince'} '#{file}' 2>/dev/null")
    when /( image )|(\.svg)/
      colorful(Image_Error,'warn') unless system("#{Yac::CONFIG["image_command"]||'eog'} '#{file}' 2>/dev/null")
    when /Office Document/
      open_office(file)
    else
      if File.extname(file) =~ /^\.(od[tfspg]|uof)$/ #Support odf uof ods odp...
        open_office(file)
      else
        File.new(file).each do |x|
          format_section(x)
        end
      end
    end
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
      colorful(Pdf_Error,'warn') unless system("#{Yac::CONFIG["pdf_edit_command"]||'ooffice'} '#{file}' 2>/dev/null")
    when /( image )|(\.svg)/
      colorful(Image_Error,'warn') unless system("#{Yac::CONFIG["image_edit_command"]||'gimp'} '#{file}' 2>/dev/null")
    when /Office Document/
      open_office(file)
    else
      if File.extname(file) =~ /^\.(od[tfspg]|uof)$/ #Support odf uof ods odp...
        open_office(file)
      else
        edit_text(file)
      end
    end
  end

  def open_office(file)
    colorful(Office_Error,'warn') unless system("#{Yac::CONFIG["office_command"]||'ooffice'} '#{file}' 2>/dev/null")
  end

  def edit_text(file)
    prepare_dir(file)
    colorful(Doc_Error,'warn') unless system("#{Yac::CONFIG["editor"] || ENV['EDITOR'] ||'vim'} '#{file}' 2>/dev/null")
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
