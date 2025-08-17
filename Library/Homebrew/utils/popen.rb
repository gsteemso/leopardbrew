module Utils
  module_function

  def popen_read(*args, &block); popen(args, "rb", &block); end

  def popen_write(*args, &block); popen(args, "wb", &block); end

  def popen(args, mode)
    IO.popen("-", mode) do |pipe|
      if pipe
        if block_given? then yield pipe
        else return pipe.read; end
      else STDERR.reopen("/dev/null", "w"); exec(*args); end
    end
  end # popen
end # Utils
