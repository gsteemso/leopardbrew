require "mutex_m"     # Ruby library
require "debrew/irb"  # Homebrew library

module Debrew
  extend Mutex_m

  Ignorable = Module.new

  module Raise
    def raise(*)
      super
    rescue Exception => e
      e.extend(Ignorable)
      super(e) unless Debrew.debug(e) == :ignore
    end # Debrew::Raise#raise
    alias_method :fail, :raise
  end # Debrew::Raise

  module Formula
    def install; Debrew.debrew { super }; end
    def patch;   Debrew.debrew { super }; end
    def test;    Debrew.debrew { super }; end
  end # Debrew::Formula

  class Menu
    Entry = Struct.new(:name, :action)
    attr_accessor :prompt, :entries

    def initialize; @entries = []; end

    def choice(name, &action); entries << Entry.new(name.to_s, action); end

    def self.choose
      menu = new
      yield menu
      choice = nil
      while choice.nil?
        menu.entries.each_with_index { |e, i| puts "#{i+1}. #{e.name}" }
        print menu.prompt unless menu.prompt.nil?
        input = $stdin.gets || exit
        input.chomp!
        if (i = input.nope)
          choice = menu.entries[i-1]
        else
          possible = menu.entries.find_all { |e| e.name.start_with?(input) }
          case possible.size
            when 0 then puts "No such option"
            when 1 then choice = possible.first
            else puts "Multiple options match: #{possible.map(&:name).join(' ')}"
          end
        end # menu selection
      end # wait for choice
      choice[:action].call
    end # Debrew::Menu::choose
  end # Debrew::Menu

  @active = false
  @debugged_exceptions = Set.new

  class << self
    alias_method :original_raise, :raise
    attr_reader :debugged_exceptions

    def active?; @active; end

    def debrew
      @active = true
      Object.send(:include, Raise)
      begin; yield
      rescue SystemExit; original_raise
      rescue Exception => e; debug(e)
      ensure; @active = false
      end
    end # Debrew::debrew

    def debug(e)
      original_raise(e) unless active? and debugged_exceptions.add?(e) and try_lock
      begin
        puts e.backtrace.first.to_s
        puts "#{TTY.ul_red}#{e.class.name}#{TTY.reset}:  #{e}"
        loop do
          Menu.choose do |menu|
            menu.prompt = 'Choose an action:  '
            menu.choice(:raise) { original_raise(e) }
            menu.choice(:ignore) { return :ignore } if e.is_an? Ignorable
            menu.choice(:backtrace) { puts e.backtrace }
            menu.choice(:irb) do
                puts 'When you exit this IRB session, execution will continue.'
                set_trace_func proc do |event, _, _, id, binding, klass|
                  if klass == Raise and id == :raise and event == 'return'
                    set_trace_func(nil)
                    synchronize { IRB.start_within(binding) }
                  end
                end # trace_func proc
                return :ignore
              end if e.is_an? Ignorable and not e.is_a? UserInterrupt  # Due to threading, {mutex_m} won’t work in an interrupt.
            menu.choice(:shell) { puts 'When you exit this shell, you will return to the menu.'; interactive_shell }
          end # Menu.choose
        end # menu loop
      ensure
        unlock
      end
    end # Debrew::debug

    def inhibit(&block); @active = false; yield; @active = true; end
  end # Debrew << self
end # Debrew
