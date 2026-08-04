module Utils
  module_function

  def pipe_from_tar(filter_tool, target_file, *input_files)
    # tar -c:  Create.
    #     -f:  use this File (in this case, standard output).
    popen_read(TAR_PATH, '-cf', '-', *input_files) do |rd|
      # In practice, this routine is only used with lzip, xz, and zstd.
      # (lzip | xz | zstd) -o:  Output to this file instead of replacing the originals.
      popen_write(filter_tool, '-o', target_file.to_s, '-') do |wr|
        buf = ''; wr.write(buf) while rd.read(FileUtils::FILE_BUFSIZE, buf)
      end
    end # do |rd|
  end # Utils::pipe_from_untar()

  def pipe_to_untar(filter_tool, target_file, extra_tar_switches = nil)
    # In practice, this routine is only used with lzip, xz, and zstd.
    # (lzip | xz | zstd) -d:  Decompress.
    #                    -c:  output to stdout (even if that’s the Console) instead of replacing the original(s).
    popen_read(filter_tool, '-dc', target_file.to_s) do |rd|
      # tar -x:  eXpand.
      #     -i:  Ignore zeroed blocks in input (there are a few flaky archives out there that require this).
      #     -f:  use this File (in this case, standard input).
      popen_write(TAR_PATH, "-xi#{extra_tar_switches}f", '-') do |wr|
        buf = ''; wr.write(buf) while rd.read(FileUtils::FILE_BUFSIZE, buf)
      end
    end # do |rd|
  end # Utils::pipe_to_untar()

  def popen(args, mode)
    IO.popen('-', mode) do |pipe|
      if pipe then if block_given? then yield pipe; else return pipe.read; end
      else STDERR.reopen('/dev/null', 'w'); exec(*args); end
    end
  end # Utils::popen()

  def popen_read(*args, &block); popen(args, 'rb', &block); end

  def popen_write(*args, &block); popen(args, 'wb', &block); end
end # Utils
