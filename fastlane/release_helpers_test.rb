require "minitest/autorun"
require "tempfile"

require_relative "release_helpers"

class AttractiveReleaseTest < Minitest::Test
  App = Struct.new(:bundle_id)
  Version = Struct.new(:version_string, :app_store_state)
  Localization = Struct.new(:locale)
  Build = Struct.new(:version, :app_version, :platform, :processing_state, :expired)

  def with_project(marketing_version: "1.0.3", build_number: "16")
    Tempfile.create(["project", ".yml"]) do |file|
      file.write(<<~YAML)
        settings:
          base:
            MARKETING_VERSION: "#{marketing_version}"
            CURRENT_PROJECT_VERSION: "#{build_number}"
      YAML
      file.flush
      yield file.path
    end
  end

  def test_reads_version_and_build_from_project_file
    with_project do |path|
      assert_equal "1.0.3", AttractiveRelease.release_version!(project_file: path)
      assert_equal "16", AttractiveRelease.build_number!(project_file: path)
    end
  end

  def test_rejects_non_numeric_build_number
    with_project(build_number: "sixteen") do |path|
      error = assert_raises(AttractiveRelease::Error) do
        AttractiveRelease.build_number!(project_file: path)
      end
      assert_match(/positive integer/, error.message)
    end
  end

  def test_requires_exact_app
    app = App.new(AttractiveRelease::APP_IDENTIFIER)
    assert_same app, AttractiveRelease.exact_app!(app)
    assert_raises(AttractiveRelease::Error) do
      AttractiveRelease.exact_app!(App.new("com.lukesteuber.attractive.tv"))
    end
  end

  def test_requires_exact_editable_version
    live = Version.new("1.0.2", "READY_FOR_SALE")
    editable = Version.new("1.0.3", "PREPARE_FOR_SUBMISSION")

    assert_same editable, AttractiveRelease.editable_version!([live, editable], version: "1.0.3")
    assert_raises(AttractiveRelease::Error) do
      AttractiveRelease.editable_version!([live, editable], version: "1.0.2")
    end
  end

  def test_inspection_can_select_a_live_version
    live = Version.new("1.0.2", "READY_FOR_SALE")
    assert_same live, AttractiveRelease.version!([live], version: "1.0.2")
  end

  def test_requires_requested_locale
    english = Localization.new("en-US")
    assert_same english, AttractiveRelease.localization!([english])
    assert_raises(AttractiveRelease::Error) do
      AttractiveRelease.localization!([Localization.new("fr-FR")])
    end
  end

  def test_selects_only_exact_valid_unexpired_build
    expired = Build.new("16", "1.0.3", "IOS", "VALID", true)
    processing = Build.new("16", "1.0.3", "IOS", "PROCESSING", false)
    wrong_train = Build.new("16", "1.0.2", "IOS", "VALID", false)
    expected = Build.new("16", "1.0.3", "IOS", "VALID", false)

    assert_same expected, AttractiveRelease.build!(
      [expired, processing, wrong_train, expected],
      version: "1.0.3",
      build_number: "16"
    )
  end

  def test_refuses_to_guess_between_duplicate_builds
    builds = 2.times.map { Build.new("16", "1.0.3", "IOS", "VALID", false) }
    assert_raises(AttractiveRelease::Error) do
      AttractiveRelease.build!(builds, version: "1.0.3", build_number: "16")
    end
  end

  def test_sorts_versions_semantically
    versions = [Version.new("1.0.10", nil), Version.new("1.0.2", nil)]
    assert_equal ["1.0.2", "1.0.10"],
                 AttractiveRelease.sort_versions(versions).map(&:version_string)
  end
end
