require "keg"

class FormulaPin
  def initialize(f); @f = f; end

  def path; PINDIR/@f.name; end

  def pin_at(version)
    PINDIR.mkpath
    version_path = @f.rack/version
    path.make_relative_symlink(version_path) unless pinned? or not version_path.exists?
  end

  def pin; pin_at(@f.rack.subdirs.map{ |d| Keg.new(d).version }.first); end

  def unpin; path.unlink if pinned?; PINDIR.rmdir_if_possible; end

  def pinned?; path.symlink?; end

  def pinnable?; @f.rack.exists? and @f.rack.subdirs.length > 0; end
end # class FormulaPin
