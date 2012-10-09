require 'tempfile'
require 'net/https'

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
    scriptfile = Tempfile.new('showterm.script')
    scriptfile.close(false)

    args = [File.join(File.dirname(File.dirname(__FILE__)), 'ext/ttyrec')]
    if cmd.size > 0
      args << '-e' + cmd.join(" ")
    end
    args << scriptfile.path

    puts "showterm is recording, quit when you're done."
    system(*args) or  raise "showterm recording failed"
    puts 'showterm recording finished'

    ret = scriptfile.open.read
    scriptfile.close(true)
    convert(ret)
  end

  # Get the current width of the terminal
  #
  # @return [Integer] number of columns
  def terminal_width
    guess = `tput cols`.to_i
    guess == 0 ? 80 : guess
  end

  # Upload the termshow to showterm.io
  #
  # @param [String] scriptfile  The ANSI dump of the terminal
  # @param [String] timingfile  The timings
  # @param [Integer] cols  The width of the terminal
  def upload!(scriptfile, timingfile, cols=terminal_width)
    puts 'uploading, please wait.'
    request = Net::HTTP::Post.new("/scripts")
    request.set_form_data(:scriptfile => scriptfile,
                          :timingfile => timingfile,
                          :cols => cols)

    response = http(request)
    raise response.body unless Net::HTTPSuccess === response
    puts response.body
  rescue => e
    raise if retried
    retried = true
    retry
  end

  private

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
    connection = Net::HTTP.new("showterm.herokuapp.com", 443)
    connection.use_ssl = true
    connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
    connection.open_timeout = 10
    connection.read_timeout = 10
    connection.start do |http|
      http.request request
    end
  rescue Timeout::Error
    raise "Could not connect to https://showterm.herokuapp.com/"
  end
end
