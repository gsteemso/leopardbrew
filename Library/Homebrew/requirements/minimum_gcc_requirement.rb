class MinimumGccRequirement < Requirement
  default_formula 'gcc'

  fatal true

  def initialize(tags)
    tags.first.to_f.to_s =~ /^(\d){1,2}(?:\.(\d))?/
    @min_version = ($1.to_i < 5 ? "#{$1}.#{$2}" : $1).to_f
    super
  end

  def message
    <<-_.undent
      You need GCC version #{@min_version.to_s} or greater to brew this formula.  The latest
      which can be brewed is version 7.5, via the `gcc` formula.
    _
  end

  satisfy do
    (ENV.cc =~ /gcc/) and
      (`#{ENV.cc} --version` =~ /(\d){1,2}\.(\d)\.\d/) and
      (actual_version = ($1.to_i < 5 ? "#{$1}.#{$2}" : $1).to_f) and
      actual_version >= @min_version
  end
end
