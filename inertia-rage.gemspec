# frozen_string_literal: true

require_relative "lib/inertia/version"

Gem::Specification.new do |spec|
  spec.name = "inertia-rage"
  spec.version = Inertia::VERSION
  spec.authors = ["Roman Samoilov"]
  spec.email = ["developers@rage-rb.dev"]

  spec.summary = "Inertia.js adapter for the Rage framework"
  spec.homepage = "https://rage-rb.dev"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/rage-rb/inertia-rage"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rage-rb", "~> 1.26"
end
