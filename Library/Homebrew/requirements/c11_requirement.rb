class C11Requirement < Requirement
  default_formula 'gcc'

  build true

  fatal true

  def message
    <<-_.undent
      You need a compiler capable of processing C11 to build this formula.  Such
      compilers include GCC 4.9 or newer (our gcc49 formula provides version
      4.9.4), or a recent‐enough version of Clang.
    _
  end

  satisfy { ENV.supports? :c11 }
end
