module Format

  def Error(x)
    colorful "Please Provide A Valid Command To Operate #{x} (~/.yacrc)",'warn'
  end

  def format_file(file)
    colorful(file,"filename") if file
    case `file "#{file}" 2>/dev/null`
    when / PDF document/
      Error('PDF')   unless system("#{Yac::CONFIG["view_pdf"]} '#{file}' ")
    when /( image)|( bitmap)|(\.svg)/
      Error('Image') unless system("#{Yac::CONFIG["view_image"]} '#{file}'")
    when /Office Document/
      open_office(file)
    else
      if File.extname(file) =~ /^\.(od[tfspg]|uof)$/ # FileType: odf uof ods odp ...
        open_office(file)
      else
        File.new(file).each {|x| format_section(x)}
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
      Error('PDF')   unless system("#{Yac::CONFIG["edit_pdf"]} '#{file}'")
    when /( image )|(\.svg)/
      Error('Image') unless system("#{Yac::CONFIG["edit_image"]} '#{file}'")
    when /Office Document/
      open_office(file)
    else
      if File.extname(file) =~ /^\.(od[tfspg]|uof)$/ # FileType: odf uof ods odp...
        open_office(file)
      else
        edit_text(file)
      end
    end
  end

  def open_office(file)
    Error('Office') unless system("#{Yac::CONFIG["edit_office"]} '#{file}'")
  end

  def edit_text(file)
    FileUtils.mkdir_p(File.dirname(file))   # Prepare Directory When Add File
    Error('Text') unless system("#{Yac::CONFIG["editor"]||ENV['EDITOR']} '#{file}'")
  end

  def colorful(stuff,level="text",line_break = true)
    stuff = empha(stuff,level)
    print "\e[%sm%s\e[0m " % [Yac::CONFIG[level],stuff.rstrip]
    print "\n" if line_break
  end

  def empha(stuff,level="text",empha_regexp=/(@(.*)@)/)
    stuff.to_s.scan(empha_regexp) do |x|
      return stuff.gsub(x[0],"\e[#{Yac::CONFIG["empha"]}m%s\e[%sm" % [x[1],Yac::CONFIG[level]])
    end
  end
end
