module Format

  def Error(x)
    colorful "Please Provide A Valid Command To Operate #{x} (~/.yacrc)",'warn'
  end

  def handle_file(file,action = 'show')
    colorful(file,"filename")

    case `file "#{file}" 2>/dev/null`
    when / PDF document/
      Error('PDF')   unless system("#{Yac::CONFIG["#{action}_pdf"]} '#{file}' ")
    when /( image)|( bitmap)|(\.svg)/
      Error('Image') unless system("#{Yac::CONFIG["#{action}_image"]} '#{file}'")
    when /Office Document/
      Error('Office') unless system("#{Yac::CONFIG["#{action}_office"]} '#{file}'")
    else
      if File.extname(file) =~ /^\.(od[tfspg]|uof)$/ # FileType: odf uof ods odp ...
        Error('Office') unless system("#{Yac::CONFIG["#{action}_office"]} '#{file}'")
      else
        action =~ 'show' ? File.new(file).each {|x| format_text(x)} : edit_text(file)
      end
    end
  end

  def edit_text(file)
    FileUtils.mkdir_p(File.dirname(file))   # Prepare Directory When Add File
    Error('Text') unless system("#{Yac::CONFIG["editor"]||ENV['EDITOR']} '#{file}'")
  end

  def format_text(section,empha_regexp = false)
    if section =~ /^(=+)\s+(.*)/
      level,section = $1.size,$2
      # Highlight keyword when searching
      section = empha(section,"head#{level}",empha_regexp) if empha_regexp
      colorful("\s"*(level-1) + section,"head#{level}")
    else
      section = empha(section,"text",empha_regexp) if empha_regexp
      colorful(section)
    end
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
