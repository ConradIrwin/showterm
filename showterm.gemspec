Gem::Specification.new do |s|
  s.name = "showterm"
  s.version = "0.1"
  s.platform = Gem::Platform::RUBY
  s.author = "Conrad Irwin"
  s.email = "conrad.irwin@gmail.com"
  s.homepage = "http://github.com/Conradirwin/showterm"
  s.summary = "Allows you to make screen casts of your terminal really easily"
  s.description = "Integrates with showterm.io for awesome sharability."
  s.files = `git ls-files`.split("\n")
  s.require_path = "lib"
  s.executables << 'showterm'
end
