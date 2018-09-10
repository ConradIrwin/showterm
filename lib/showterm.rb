require 'tempfile'
require 'shellwords'
require 'net/https'
require 'securerandom'

module Showterm
  extend self

  # Record a terminal session.
  #
  # If a command is given, use that command; otherwise the current user's
  # login shell will be used.
  #
  # @param [*String] cmd
  # @return [scriptfile, timingfile]  the two halves of a termshow
  def record!(*cmd)
    ret = if use_script?
      record_with_script(*cmd)
    else
      record_with_ttyrec(*cmd)
    end
    ret
  end

  # Get the current width of the terminal
  #
  # @return [Integer] number of columns
  def terminal_width
    guess = `tput cols`.to_i
    guess == 0 ? 80 : guess
  end


  # Get the current height of the terminal
  #
  # @return [Integer] number of lines
  def terminal_height
    guess = `tput lines`.to_i
    guess == 0 ? 25 : guess
  end

  # Upload the termshow to showterm.io
  #
  # @param [String] scriptfile  The ANSI dump of the terminal
  # @param [String] timingfile  The timings
  # @param [Integer] cols  The width of the terminal
  # @param [String] secret  The shared secret that will allow deleting this showterm.
  def upload!(scriptfile, timingfile, cols=terminal_width, lines=terminal_height, secret=shared_secret)
    with_retry do
      request = Net::HTTP::Post.new("/scripts")
      request.set_form_data(:scriptfile => scriptfile,
                            :timingfile => timingfile,
                            :cols => cols,
                            :lines => lines,
                            :secret => secret)

      response = http(request)
      raise response.body unless Net::HTTPSuccess === response
      response.body
    end
  end

  # Delete from showterm.io
  #
  # @param [String] url  The URL of the showterm to delete
  # @param [String] secret  The secret with which it was uploaded.
  def delete!(url, secret=shared_secret)

    request = Net::HTTP::Delete.new(URI(url).path)
    request.set_form_data(:secret => secret)
    response = http(request)

    raise response.body unless Net::HTTPSuccess === response
    response.body
  end

  private

  def with_retry(n=1, &block)
    yield
  rescue
    raise if n == 0
    n -= 1
    retry
  end

  def shared_secret
    path = File.expand_path("~/.showterm")
    unless File.exist?(path)
      File.open(path, 'w') do |f|
        f.write SecureRandom.hex(16)
      end
    end
    File.read(path).strip
  end

  # Get a temporary file that will be deleted when the program exits.
  def temp_file
    f = Tempfile.new('showterm')
    f.close(false)
    at_exit{ f.close(true) }
    f
  end

  # Should we try recording using `script`?
  #
  # This is a hard question to answer, so we just try it and see whether it
  # looks like it gives sane results.
  #
  # We prefer to use script if it works because ttyrec gives really horrible
  # errors about missing ptys. This might be fixable by compiling with the
  # correct flags; but as script seems to work on these platforms, let's just
  # use that.
  #
  # @return [Boolean] whether the script command looks like it's working.
  def use_script?
    scriptfile, timingfile = [temp_file, temp_file]
    `#{script_command(scriptfile, timingfile, ['echo', 'foo'])}`
    scriptfile.open.read =~ /foo/ && timingfile.open.read =~ /^[0-9]/
  end

  # Record using the modern version of 'script'
  #
  # @param [*String] command to run
  # @return [scriptfile, timingfile]
  def record_with_script(*cmd)
    scriptfile, timingfile = [temp_file, temp_file]
    system script_command(scriptfile, timingfile, cmd)
    [scriptfile.open.read, timingfile.open.read]
  end

  def script_command(scriptfile, timingfile, cmd)
    args = ['script']
    args << '-c' + cmd.join(" ") if cmd.size > 0
    args << '-q'
    args << '-t'
    args << scriptfile.path

    "#{args.map{ |x| Shellwords.escape(x) }.join(" ")} 2>#{Shellwords.escape(timingfile.path)}"
  end


  # Record using system ttyrec
  #
  # @param [*String] command to run
  # @return [scriptfile, timingfile]
  def record_with_ttyrec(*cmd)
    scriptfile = temp_file

    args = ['ttyrec']
    if cmd.size > 0
      args << '-e' + cmd.join(" ")
    end
    args << scriptfile.path

    status = system(*args)
    raise TTYREC_NOT_INSTALLED_ERROR if status.nil? && `which ttyrec`.empty?

    convert(scriptfile.open.read)
  end

  TTYREC_NOT_INSTALLED_ERROR = <<~HEREDOC


      Showterm requires ttyrec to availible in your path.
      Try installing via: `brew install ttyrec` if you can.
      Brew patches ttyrec on installation in order to address 
      a macOS openpty() issue (https://github.com/Homebrew/homebrew-core/pull/21922)
      Also, definitely check out http://0xcc.net/ttyrec/
    HEREDOC

  # The original version of showterm used the 'script' binary.
  #
  # Unfortunately that varies wildly from platform to platform, so we now
  # bundle 'ttyrec' instead. This converts between the output of ttyrec and
  # the output of 'script' so that the server remains solely a 'script' server.
  #
  # @param [String] ttyrecord
  # @return [scriptfile, timingfile]
  def convert(ttyrecord)
    ttyrecord.force_encoding('BINARY') if ttyrecord.respond_to?(:force_encoding)
    raise "Invalid ttyrecord: #{ttyrecord.inspect}" if ttyrecord.size < 12

    scriptfile = "Converted from ttyrecord\n"
    timingfile = ""

    prev_sec, prev_usec = ttyrecord.unpack('VV')
    pos = 0

    while pos < ttyrecord.size
      sec, usec, bytes = ttyrecord[pos..(pos + 12)].unpack('VVV')
      time = (sec - prev_sec) + (usec - prev_usec) * 0.000_001

      prev_sec = sec
      prev_usec = usec

      timingfile << "#{time} #{bytes}\n"
      scriptfile << ttyrecord[(pos + 12)...(pos + 12 + bytes)]

      pos += 12 + bytes
    end

    [scriptfile, timingfile]
  end

  def http(request)
    connection = Net::HTTP.new(url.host, url.port)
    if url.scheme =~ /https/i
      connection.use_ssl = true
      connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    connection.open_timeout = 10
    connection.read_timeout = 10
    connection.start do |http|
      http.request request
    end
  rescue Timeout::Error
    raise "Could not connect to #{@url.to_s}"
  end

  def url
    @url ||= URI(ENV["SHOWTERM_SERVER"] || "https://showterm.herokuapp.com")
  end
end
