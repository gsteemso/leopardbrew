module Homebrew
  def uncheckpoint
    def uncheckroot(fname = false)
      pn, msg_fragment = fname ? [CHECKPOINTS/fname, "#{fname} has"] : [CHECKPOINTS, 'There are']
      if not pn.directory? or pn.empty? then puts "#{msg_fragment} no checkpoints to remove."
      else pn.each_child{ |ch| ch.rmtree }; pn.rmdir_if_possible; end
    end

    if ARGV.named.empty? then uncheckroot; else ARGV.formulae.each{ |f| uncheckroot f.name }; end
  end # uncheckpoint
end # Homebrew
