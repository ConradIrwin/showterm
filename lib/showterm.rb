require 'json'
require 'tempfile'
require 'net/https'

module Showterm
  extend self

  def record!(*cmd)

    scriptfile = Tempfile.new('showterm.script')
    timingfile = Tempfile.new('showterm.time')

    scriptfile.close(false)
    timingfile.close(false)

    args = []
    if cmd.size > 0
      args << '-c' + cmd.join(" ")
    end

    args << '-q'
    args << '-t' + timingfile.path
    args << scriptfile.path

    puts "showterm is recording, quit when you're done."

    unless system('script', *args)
      raise "Could not run 'script', please check that it's installed"
    end

    puts 'showterm recording finished'

    [scriptfile.path, timingfile.path]
  end

  def upload!(scriptfile, timingfile, cols=80)
    puts 'uploading, please wait.'
    request = Net::HTTP::Post.new("/scripts")
    request.set_form_data(:scriptfile => File.read(scriptfile),
                          :timingfile => File.read(timingfile),
                          :cols => cols)

    response = http(request)
    raise response.body unless Net::HTTPSuccess === response
    puts response.body
  end

  private

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
