require "requirement"

class LanguageModuleRequirement < Requirement
  fatal true

  def initialize(language, module_name, import_name = nil, brewed = false)
    @language = language
    @module_name = module_name
    @import_name = import_name || module_name
    @require_brewed = brewed
    super([language, module_name, import_name])
  end

  satisfy(:build_env => false) { quiet_system(*the_test) }

  def message; <<-EOS.undent
      Unsatisfied dependency:  #{@module_name}
      Leopardbrew does not provide #{@language.to_s.capitalize} dependencies; install with:
          #{command_line} #{@module_name}
    EOS
  end

  def the_test
    case @language
      when :chicken then %W[/usr/bin/env csi -e (use\ #{@import_name})]
      when :jruby then %W[/usr/bin/env jruby -rubygems -e require\ '#{@import_name}']
      when :lua then %W[/usr/bin/env luarocks-5.2 show #{@import_name}]
      when :lua51 then %W[/usr/bin/env luarocks-5.1 show #{@import_name}]
      when :node then %W[/usr/bin/env node -e require('#{@import_name}');]
      when :ocaml then %W[/usr/bin/env opam list --installed #{@import_name}]
      when :perl
        if @require_brewed then %W[#{Formula['perl'].opt_bin}/perl -e use\ #{@import_name}]
        else %W[/usr/bin/env perl -e use\ #{@import_name}]; end
      when :python
        if @require_brewed then %W[#{Formula['python'].opt_bin}/python -c import\ #{@import_name}]
        else %W[/usr/bin/env python -c import\ #{@import_name}]; end
      when :python3
        if @require_brewed or not `which python3`.choke
          %W[#{Formula['python3'].opt_bin}/python3 -c import\ #{@import_name}]
        else %W[/usr/bin/env python3 -c import\ #{@import_name}]; end
      when :rbx then %W[/usr/bin/env rbx -rubygems -e require\ '#{@import_name}']
      when :ruby
        if @require_brewed then %W[#{Formula['ruby'].opt_bin}/ruby -rubygems -e require\ '#{@import_name}']
        else %W[/usr/bin/env ruby -rubygems -e require\ '#{@import_name}']; end
      else raise RuntimeError, "module specified for unknown language “#{@language}”"
    end # case @language
  end # the_test

  def command_line
    case @language
      when :chicken then "chicken-install"
      when :jruby   then "jruby -S gem install"
      when :lua     then "luarocks-5.2 install"
      when :lua51   then "luarocks-5.1 install"
      when :node    then "npm install"
      when :ocaml   then "opam install"
      when :perl
        if @require_brewed then "#{Formula['perl'].opt_bin}/cpan -i"
        else 'cpan -i'; end
      when :python
        if @require_brewed then "#{Formula['python'].opt_bin}/pip install"
        else 'pip install'; end
      when :python3
        if @require_brewed or not `which python3`.choke
          "#{Formula['python3'].opt_bin}/pip3 install -U"
        else 'pip3 install -U'; end
      when :rbx     then "rbx gem install"
      when :ruby
        if @require_brewed then "#{Formula['ruby'].opt_bin}/gem install"
        else 'gem install'; end
    end # case @language
  end # command_line
end # LanguageModuleRequirement
