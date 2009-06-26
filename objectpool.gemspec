## objectpool.gemspec
#

Gem::Specification::new do |spec|
  spec.name = "objectpool"
  spec.version = "0.0.1"
  spec.platform = Gem::Platform::RUBY
  spec.summary = "objectpool"

  spec.files = ["lib", "lib/objectpool.rb", "lib/objectpool.rb.werks", "rakefile", "README", "README.erb"]
  spec.executables = []
  
  spec.require_path = "lib"

  spec.has_rdoc = true
  spec.test_files = nil
  #spec.add_dependency 'lib', '>= version'
  #spec.add_dependency 'fattr'

  spec.extensions.push(*[])

  spec.rubyforge_project = "codeforpeople"
  spec.author = "Ara T. Howard"
  spec.email = "ara.t.howard@gmail.com"
  spec.homepage = "http://github.com/ahoward/objectpool/tree/master"
end
