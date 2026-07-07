# Define the parent namespace before requiring the individual helper files.
# Each helper file opens a compact namespace (e.g. `module
# Acceptance::Helpers::ManifestHelpers`), which raises a NameError on Ruby
# unless `Acceptance` and `Acceptance::Helpers` already exist. The nested
# definition here is required for that load order, so the compact-style cop
# is disabled for this block.
# rubocop:disable Style/ClassAndModuleChildren
module Acceptance
  module Helpers
  end
end
# rubocop:enable Style/ClassAndModuleChildren

rb_files = File.expand_path('helpers/**/*.rb', __dir__)
Dir.glob(rb_files).sort_by(&:to_s).each { |file| require file }
