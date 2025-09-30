class Cxx11Requirement < Requirement
  default_formula 'gcc'

  build true

  fatal true

  def message
    <<-_.undent
      You need a compiler capable of processing C++11 to build this formula.  Such
      compilers include GCC 4.8.1 or newer (our gcc48 formula provides version
      4.8.5), or a recent‐enough version of Clang.
    _
  end

  satisfy { ENV.supports? :cxx11 }
end
