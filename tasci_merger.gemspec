Gem::Specification.new do |s|
  s.name        = 'tasci_merger'
  s.version     = '0.0.0'
  s.date        = '2015-02-06'
  s.summary     = "Merger utility for TASCI scored sleep files."
  s.description = "Merger utility for TASCI scored sleep files, built for the Division of Sleep and Circadian Disorders at BWH."
  s.authors     = ["Piotr Mankowski"]
  s.email       = 'pmankowski@partners.org'
  s.files       = %w(LICENSE README.md tasci_merger.gemspec lib/tasci_merger.rb lib/man_merger.rb lib/labtime.rb)
  s.require_path = 'lib'
  s.homepage    =
      'https://github.com/pmanko/tasci_merger'
  s.license       = 'MIT'
  s.executables << 'merge_tasci'

  s.required_ruby_version = '>= 2.1.0'

  s.add_dependency "activesupport", '~> 4.2', '>= 4.2.0'

end
