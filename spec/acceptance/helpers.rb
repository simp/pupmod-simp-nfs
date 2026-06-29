# Define the parent namespace before requiring the individual helper files.
# Each helper file opens a compact namespace (e.g. `module
# Acceptance::Helpers::ManifestHelpers`), which raises a NameError on Ruby
# unless `Acceptance` and `Acceptance::Helpers` already exist.
module Acceptance
  module Helpers
  end
end

rb_files = File.expand_path('helpers/**/*.rb', __dir__)
Dir.glob(rb_files).sort_by(&:to_s).each { |file| require file }
