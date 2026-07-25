module InstallRenamed
  def install_p(_, new_basename); super { |src, dst| src.directory? ? dst : append_default_if_different(src, dst) }; end

  def cp_path_sub(pattern, replacement); super { |src, dst| append_default_if_different(src, dst) }; end

  def +(path); super(path).extend(InstallRenamed); end

  def /(path); super(path).extend(InstallRenamed); end

  private

  def append_default_if_different(src, dst)
    (dst.file? and not FileUtils.identical?(src, dst)) ? Pathname("#{dst}.default") : dst
  end
end # module InstallRenamed
