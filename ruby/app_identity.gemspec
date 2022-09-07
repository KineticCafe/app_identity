# -*- encoding: utf-8 -*-
# stub: app_identity 1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "app_identity".freeze
  s.version = "1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "rubygems_mfa_required" => "true" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Austin Ziegler".freeze, "Kinetic Commerce".freeze]
  s.date = "2022-08-31"
  s.description = "AppIdentity is a Ruby implementation of the Kinetic Commerce application\nidentity proof algorithm as described in its [spec][].".freeze
  s.email = ["aziegler@kineticcommerce.com".freeze, "dev@kineticcommerce.com".freeze]
  s.executables = ["app-identity-suite-ruby".freeze]
  s.extra_rdoc_files = ["Changelog.md".freeze, "Contributing.md".freeze, "Licence.md".freeze, "Manifest.txt".freeze, "README.md".freeze, "licences/APACHE-2.0.txt".freeze, "licences/DCO.txt".freeze, "spec.md".freeze]
  s.files = [".rdoc_options".freeze, "Changelog.md".freeze, "Contributing.md".freeze, "Licence.md".freeze, "Manifest.txt".freeze, "README.md".freeze, "Rakefile".freeze, "bin/app-identity-suite-ruby".freeze, "lib/app_identity.rb".freeze, "lib/app_identity/app.rb".freeze, "lib/app_identity/error.rb".freeze, "lib/app_identity/faraday_middleware.rb".freeze, "lib/app_identity/internal.rb".freeze, "lib/app_identity/rack_middleware.rb".freeze, "lib/app_identity/validation.rb".freeze, "lib/app_identity/versions.rb".freeze, "licences/APACHE-2.0.txt".freeze, "licences/DCO.txt".freeze, "spec.md".freeze, "support/app_identity/suite.rb".freeze, "support/app_identity/suite/generator.rb".freeze, "support/app_identity/suite/optional.json".freeze, "support/app_identity/suite/program.rb".freeze, "support/app_identity/suite/required.json".freeze, "support/app_identity/suite/runner.rb".freeze, "support/app_identity/support.rb".freeze, "test/minitest_helper.rb".freeze, "test/test_app_identity.rb".freeze, "test/test_app_identity_app.rb".freeze, "test/test_app_identity_rack_middleware.rb".freeze]
  s.homepage = "https://github.com/KineticCafe/app-identity/tree/main/ruby/".freeze
  s.licenses = ["MIT".freeze]
  s.rdoc_options = ["--main".freeze, "README.md".freeze]
  s.rubygems_version = "3.3.7".freeze
  s.summary = "AppIdentity is a Ruby implementation of the Kinetic Commerce application identity proof algorithm as described in its [spec][].".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<optimist>.freeze, ["~> 3.0"])
    s.add_development_dependency(%q<minitest>.freeze, ["~> 5.16"])
    s.add_development_dependency(%q<hoe-doofus>.freeze, ["~> 1.0"])
    s.add_development_dependency(%q<hoe-gemspec2>.freeze, ["~> 1.1"])
    s.add_development_dependency(%q<hoe-git2>.freeze, ["~> 1.7"])
    s.add_development_dependency(%q<minitest-autotest>.freeze, ["~> 1.0"])
    s.add_development_dependency(%q<minitest-bisect>.freeze, ["~> 1.2"])
    s.add_development_dependency(%q<minitest-focus>.freeze, ["~> 1.1"])
    s.add_development_dependency(%q<minitest-pretty_diff>.freeze, ["~> 0.1"])
    s.add_development_dependency(%q<rack-test>.freeze, ["~> 0.6"])
    s.add_development_dependency(%q<rake>.freeze, [">= 10.0", "< 14.0"])
    s.add_development_dependency(%q<rdoc>.freeze, ["~> 6.4"])
    s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.7"])
    s.add_development_dependency(%q<standard>.freeze, ["~> 1.0"])
    s.add_development_dependency(%q<hoe>.freeze, ["~> 3.24"])
  else
    s.add_dependency(%q<optimist>.freeze, ["~> 3.0"])
    s.add_dependency(%q<minitest>.freeze, ["~> 5.16"])
    s.add_dependency(%q<hoe-doofus>.freeze, ["~> 1.0"])
    s.add_dependency(%q<hoe-gemspec2>.freeze, ["~> 1.1"])
    s.add_dependency(%q<hoe-git2>.freeze, ["~> 1.7"])
    s.add_dependency(%q<minitest-autotest>.freeze, ["~> 1.0"])
    s.add_dependency(%q<minitest-bisect>.freeze, ["~> 1.2"])
    s.add_dependency(%q<minitest-focus>.freeze, ["~> 1.1"])
    s.add_dependency(%q<minitest-pretty_diff>.freeze, ["~> 0.1"])
    s.add_dependency(%q<rack-test>.freeze, ["~> 0.6"])
    s.add_dependency(%q<rake>.freeze, [">= 10.0", "< 14.0"])
    s.add_dependency(%q<rdoc>.freeze, ["~> 6.4"])
    s.add_dependency(%q<simplecov>.freeze, ["~> 0.7"])
    s.add_dependency(%q<standard>.freeze, ["~> 1.0"])
    s.add_dependency(%q<hoe>.freeze, ["~> 3.24"])
  end
end
