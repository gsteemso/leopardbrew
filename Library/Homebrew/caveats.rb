class Caveats
  attr_reader :f

  def initialize(f)
    @f = f
    @value = _caveats
  end

  def caveats; @value; end # _caveats

  def empty?
    @value.nil? or @value == ''
  end

  private

  def _caveats
    _caveats = []
    s = f.caveats.to_s
    _caveats << s.chomp if s.length > 0
    _caveats << enhancements_caveats
    _caveats << keg_only_caveats
    _caveats << bash_completion_caveats
    _caveats << zsh_completion_caveats
    _caveats << fish_completion_caveats
    _caveats << plist_caveats
    _caveats << python_caveats
    _caveats << app_caveats
    _caveats << elisp_caveats
    _caveats << ''
    _caveats.compact.join("\n\n")
  end # _caveats

  def keg
    @keg ||= [f.opt_prefix, f.linked_keg, f.prefix].map{ |d| d.resolved_path }.uniq.map{ |d| Keg.new(d) rescue nil }.compact.first
  end

  def enhancements_caveats
    def list_aid_groups
      out = []
      f.named_enhancements.each{ |eg| out << "{#{eg * ' + '}}" }
      out.list
    end
    ne = f.named_enhancements
    return if ne.empty?
    s = ne.length
    ss = ne.flatten.uniq.length
    <<-_.undent.rewrap
      This formula will take advantage of the formul#{plural(ss, 'æ', 'a')} #{list_aid_groups} if
      #{plural(ss, plural(s, 'any of them', 'they'), 'it', plural(s, 'either', 'both'))}
      happen#{plural(ss, '', 's', plural(s))} to be installed at the time of brewing.  Should
      #{plural(ss, plural(s, 'any', 'they'), 'it', plural(s, 'either or both', 'the two'))} be
      installed later, this formula will not benefit unless reïnstalled.
    _
  end # enhancements_caveats

  def keg_only_caveats
    return unless f.keg_only?

    s = "This formula is keg-only, which means it is not symlinked into\n#{HOMEBREW_PREFIX}.\n\n"
    s << "#{f.keg_only_reason}\n\n"
    if f.lib.directory? or f.include.directory?
      s << <<-EOS.undent
          Generally there are no consequences of this for you. If you build your
          own software and it requires this formula, you’ll need to add to your
          build variables:
        EOS
      s << "    LDFLAGS:  -L#{f.opt_lib}\n" if f.lib.directory?
      s << "    CPPFLAGS: -I#{f.opt_include}" if f.include.directory?
    end
  end # keg_only_caveats

  def bash_completion_caveats
    "Bash completion is installed to:\n    #{HOMEBREW_PREFIX}/etc/bash_completion.d" \
      if keg and keg.completion_installed?(:bash) and keg.linked?
  end

  def zsh_completion_caveats
    "zsh completion is installed to:\n    #{HOMEBREW_PREFIX}/share/zsh/site-functions" \
      if keg and keg.completion_installed?(:zsh) and keg.linked?
  end # zsh_completion_caveats

  def fish_completion_caveats
    "fish completion is installed to:\n    #{HOMEBREW_PREFIX}/share/fish/vendor_completions.d" \
      if keg and keg.completion_installed?(:fish) and keg.linked?
  end # fish_completion_caveats

  def plist_caveats
    s = []
    if f.plist or (keg and keg.plist_installed?)
      destination = if f.plist_startup
        "/Library/LaunchDaemons"
      else
        "~/Library/LaunchAgents"
      end

      plist_filename = if f.plist
        f.plist_path.basename
      else
        File.basename Dir["#{keg}/*.plist"].first
      end
      plist_link = "#{destination}/#{plist_filename}"
      plist_domain = f.plist_path.basename(".plist")
      destination_path = Pathname.new File.expand_path destination
      plist_path = destination_path/plist_filename

      # we readlink because this path probably doesn't exist since caveats
      # occurs before the link step of installation
      # Yosemite security measures mildly tighter rules:
      # https://github.com/Homebrew/homebrew/issues/33815
      if not (plist_path.file? and plist_path.symlink?)
        if f.plist_startup
          s << "To have launchd start #{f.full_name} at startup:"
          s << "    sudo mkdir -p #{destination}" unless destination_path.directory?
          s << "    sudo cp -fv #{f.opt_prefix}/*.plist #{destination}"
          s << "    sudo chown root #{plist_link}"
        else
          s << "To have launchd start #{f.full_name} at login:"
          s << "    mkdir -p #{destination}" unless destination_path.directory?
          s << "    ln -sfv #{f.opt_prefix}/*.plist #{destination}"
        end
        s << "Then to load #{f.full_name} now:"
        if f.plist_startup
          s << "    sudo launchctl load #{plist_link}"
        else
          s << "    launchctl load #{plist_link}"
        end
      # For startup plists, we cannot tell whether it's running on launchd,
      # as it requires for `sudo launchctl list` to get real result.
      elsif f.plist_startup
        s << "To reload #{f.full_name} after an upgrade:"
        s << "    sudo launchctl unload #{plist_link}"
        s << "    sudo cp -fv #{f.opt_prefix}/*.plist #{destination}"
        s << "    sudo chown root #{plist_link}"
        s << "    sudo launchctl load #{plist_link}"
      elsif Kernel.system "/bin/launchctl list #{plist_domain} &>/dev/null"
        s << "To reload #{f.full_name} after an upgrade:"
        s << "    launchctl unload #{plist_link}"
        s << "    launchctl load #{plist_link}"
      else
        s << "To load #{f.full_name}:"
        s << "    launchctl load #{plist_link}"
      end

      if f.plist_manual
        s << "Or, if you don't want/need launchctl, you can just run:"
        s << "    #{f.plist_manual}"
      end

      s << "" << "WARNING: launchctl will fail when run under tmux." if ENV["TMUX"]
    end
    s.join("\n") unless s.empty?
  end # plist_caveats

  def python_caveats
    return unless keg
    return unless keg.python_site_packages_installed?

    s = nil
    homebrew_site_packages = Language::Python.homebrew_site_packages
    user_site_packages = Language::Python.user_site_packages "python"
    pth_file = user_site_packages/"homebrew.pth"
    instructions = <<-EOS.undent.gsub(/^/, "    ")
      mkdir -p #{user_site_packages}
      echo 'import site; site.addsitedir("#{homebrew_site_packages}")' >> #{pth_file}
    EOS

    if f.keg_only?
      keg_site_packages = f.opt_prefix/"lib/python2.7/site-packages"
      unless Language::Python.in_sys_path?("python", keg_site_packages)
        s = <<-EOS.undent
          If you need Python to find bindings for this keg-only formula, run:
              echo #{keg_site_packages} >> #{homebrew_site_packages/f.name}.pth
        EOS
        s += instructions unless Language::Python.reads_brewed_pth_files?("python")
      end
      return s
    end

    return if Language::Python.reads_brewed_pth_files?("python")

    if !Language::Python.in_sys_path?("python", homebrew_site_packages)
      s = <<-EOS.undent
        Python modules are installed and Leopardbrew’s site-packages is not
        in your Python sys.path, so you will not be able to import the modules
        this formula installs.  If you plan to develop with these modules,
        please run:
      EOS
      s += instructions
    elsif keg.python_pth_files_installed?
      s = <<-EOS.undent
        This formula installs .pth files to Leopardbrew’s site-packages and
        your Python isn’t configured to process them, so you will not be able to
        import the modules this formula installs. If you plan to develop with
        these modules, please run:
      EOS
      s += instructions
    end
    s.chomp
  end # python_caveats

  def app_caveats
    if keg and keg.app_installed?
      <<-EOS.undent.chomp
        .app bundles are installed.
        Run “brew linkapps #{keg.name}” to symlink these to /Applications.
      EOS
    end
  end # app_caveats

  def elisp_caveats
    return if f.keg_only?
    if keg and keg.elisp_installed?
      <<-EOS.undent.chomp
        Emacs Lisp files are installed to:
        #{HOMEBREW_PREFIX}/share/emacs/site-lisp/

        Add the following to your init file to have Lisp packages installed by
        Homebrew added to your load-path:
        (let ((default-directory "#{HOMEBREW_PREFIX}/share/emacs/site-lisp/"))
          (normal-top-level-add-subdirs-to-load-path))
      EOS
    end
  end # elisp_caveats
end # Caveats
