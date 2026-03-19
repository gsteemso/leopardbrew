require 'formula'

module Homebrew
  def options
    if ARGV.include? '--all' then puts_options Formula.to_a
    elsif ARGV.include? '--installed' then puts_options Formula.installed
    else
      raise FormulaUnspecifiedError if ARGV.named.empty?
      puts_options ARGV.formulae
    end
  end # Homebrew#options()

  def puts_options(formulae)
    formulae.each do |f|
      next if f.options.empty?
      if ARGV.include? '--compact' then puts f.options.as_flags.sort.list
      else
        puts f.full_name if formulae.length > 1
        dump_options_for_formula f
        puts
      end
    end # each formula |f|
  end # Homebrew#puts_options()

  def dump_options_for_formula(f); f.options.sort_by(&:flag).each{ |opt| puts "#{opt.flag}\n\t#{opt.description}" }; end
end # Homebrew
