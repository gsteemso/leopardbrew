require 'compilers'

class Cxx11Requirement < Requirement
  default_formula 'gcc'

  fatal true

  def message
    <<-_.undent
      You need a compiler capable of processing C++11 to build this formula.  Such
      compilers include GCC 4.7.2 or newer (our gcc47 formula provides version
      4.7.4), or a recent‐enough version of Clang.
    _
  end

  satisfy { ENV.supports_cxx11? }
end
