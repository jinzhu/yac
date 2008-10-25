module Format
  Pdf_Error = "Please Modify ~/.yacrc To Provide A Valid Command To Open PDF Document"
  Image_Error = "Please Modify ~/.yacrc To Provide A Valid Command To Open Image Document"

  def format_file(file)
    @level = 0
    case `file #{file}`
    when / PDF /
      puts Pdf_Error unless system("#{Yac::CONFIG["pdf_command"]||'evince'} #{file}")
    when /( image )|(\.svg)/
      puts Image_Error unless system("#{Yac::CONFIG["pic_command"]||'eog'} #{file}")
    else
      File.new(file).each do |x|
        format_section(x)
      end
    end
  end

  def format_section(section,search = false)
    case section
    when /^(=+)\s+(.*)/
      @level = search ? 1 : $1.size
      colorful("\s"*2*(@level-1) + $2,"head#{@level}")
    when /^(\s*)#/
    else
      colorful(section.sub(/^\#/,"#").sub(/^\s*/, "\s" * @level * 2 ))
    end
  end

  def editor
    Yac::CONFIG["editor"] || ENV['EDITOR'] || "vim"
  end

  def title_of_file(f)
    f[0..((f.rindex('.')||0) - 1)]
  end

  def colorful(stuff,level="text",line_break = true)
    stuff = empha(stuff,level)
    print "\033[%sm%s\033[0m" % [Yac::CONFIG[level],stuff.rstrip]
    print "\n" if line_break
  end

  def empha(stuff,level="text",empha_regexp=/(@@@(.*)@@@)/)
    stuff.scan(empha_regexp) do |x|
      return stuff.gsub(x[0],"\033[0m\033[#{Yac::CONFIG["empha"].to_s}m%s\033[0m\033[%sm" % [x[1],Yac::CONFIG[level]])
    end
  end

  def show_possible_result
    unless @all_result.to_s.empty?
      colorful("ALL POSSIBLE RESULT:","possible_result_title")
      colorful(@all_result.join("\s"*2),"possible_result_content")
    end
  end
end
