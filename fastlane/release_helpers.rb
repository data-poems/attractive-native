require "rubygems/version"
require "yaml"

module AttractiveRelease
  APP_IDENTIFIER = "com.lukesteuber.attractive"
  EDITABLE_VERSION_STATE = "PREPARE_FOR_SUBMISSION"
  IOS_PLATFORM = "IOS"
  PROJECT_FILE = File.expand_path("../project.yml", __dir__)

  class Error < StandardError; end

  def self.project_setting!(name, project_file: PROJECT_FILE)
    project = YAML.safe_load_file(project_file, aliases: true)
    value = project.dig("settings", "base", name).to_s.strip
    raise Error, "#{name} is missing from #{project_file}" if value.empty?

    value
  rescue Psych::Exception, SystemCallError => error
    raise Error, "could not read #{project_file}: #{error.message}"
  end

  def self.release_version!(project_file: PROJECT_FILE)
    project_setting!("MARKETING_VERSION", project_file: project_file)
  end

  def self.build_number!(project_file: PROJECT_FILE)
    value = project_setting!("CURRENT_PROJECT_VERSION", project_file: project_file)
    raise Error, "CURRENT_PROJECT_VERSION must be a positive integer" unless value.match?(/\A[1-9]\d*\z/)

    value
  end

  def self.exact_app!(app, bundle_id: APP_IDENTIFIER)
    raise Error, "App Store Connect app #{bundle_id} was not found" unless app
    raise Error, "expected app #{bundle_id}, got #{app.bundle_id}" unless app.bundle_id == bundle_id

    app
  end

  def self.version!(versions, version:)
    match = versions.find { |candidate| candidate.version_string.to_s == version.to_s }
    raise Error, "App Store Connect version #{version} does not exist" unless match

    match
  end

  def self.editable_version!(versions, version:)
    match = version!(versions, version: version)
    return match if match.app_store_state == EDITABLE_VERSION_STATE

    raise Error,
          "version #{version} is #{match.app_store_state}, not #{EDITABLE_VERSION_STATE}"
  end

  def self.localization!(localizations, locale: "en-US")
    match = localizations.find { |candidate| candidate.locale == locale }
    raise Error, "localization #{locale} does not exist" unless match

    match
  end

  def self.build!(builds, version:, build_number:, platform: IOS_PLATFORM)
    matches = builds.select do |candidate|
      candidate.version.to_s == build_number.to_s &&
        candidate.app_version.to_s == version.to_s &&
        candidate.platform.to_s == platform &&
        candidate.processing_state == "VALID" &&
        !candidate.expired
    end

    raise Error, "no VALID, unexpired #{platform} build #{version} (#{build_number}) found" if matches.empty?
    raise Error, "multiple builds matched #{version} (#{build_number}); refusing to guess" if matches.length > 1

    matches.first
  end

  def self.sort_versions(versions)
    versions.sort_by { |version| Gem::Version.new(version.version_string.to_s) }
  rescue ArgumentError => error
    raise Error, "invalid App Store version: #{error.message}"
  end
end
