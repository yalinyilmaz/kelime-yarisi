require 'minitest/autorun'
require 'tmpdir'
require_relative '../fastlane/dev_release'

class DevReleaseTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir('ky-release-test-')
    @pubspec = File.join(@directory, 'pubspec.yaml')
    @source = "name: kelime_yarisi\nversion: 0.1.0+41 # keep comment\n\nflutter:\n  uses-material-design: true\n"
    File.write(@pubspec, @source)
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_check_does_not_change_version_or_unrelated_content
    assert_equal ['0.1.0', '41'], DevRelease.version(@pubspec)
    assert_equal @source, File.read(@pubspec)
  end

  def test_build_increases_once_and_keeps_pubspec_content
    assert_equal ['0.1.0', '42'], DevRelease.version(@pubspec, bump: true)
    assert_equal @source.sub('0.1.0+41', '0.1.0+42'), File.read(@pubspec)
    assert_equal ['0.1.0', '42'], DevRelease.version(@pubspec)
  end

  def test_marketing_version_still_increments_build
    assert_equal ['1.2.3', '42'], DevRelease.version(@pubspec, requested: '1.2.3', bump: true)
    assert_equal ['1.2.3', '42'], DevRelease.version(@pubspec)
  end

  def test_invalid_and_backward_versions_leave_pubspec_untouched
    ['0.0.9', 'hello', '01.2.3', '1.2.3+7', "1.2.3\nother"].each do |requested|
      assert_raises(RuntimeError) { DevRelease.version(@pubspec, requested: requested, bump: true) }
      assert_equal @source, File.read(@pubspec)
    end
  end

  def test_android_maximum_build_cannot_overflow
    File.write(@pubspec, "version: 1.0.0+2100000000\n")
    assert_raises(RuntimeError) { DevRelease.version(@pubspec, bump: true) }
    assert_equal "version: 1.0.0+2100000000\n", File.read(@pubspec)
  end

  def test_only_dsn_and_public_release_metadata_reach_dart
    path = File.join(@directory, 'sentry.json')
    DevRelease.write_json(path, 'SENTRY_DSN' => 'https://public@example.test/1')
    result = DevRelease.defines(path, 'app@0.1.0+42', '42', 'public-uuid')
    assert_equal %w[QUESTION_POOL_ENABLED SENTRY_DIST SENTRY_DSN SENTRY_PROGUARD_UUID SENTRY_RELEASE], result.keys.sort
    DevRelease.write_json(path, 'SENTRY_DSN' => 'https://public@example.test/1', 'SENTRY_AUTH_TOKEN' => 'must-not-ship')
    error = assert_raises(RuntimeError) { DevRelease.defines(path, 'app@1+42', '42') }
    refute_includes error.message, 'must-not-ship'
  end

  def test_malformed_credentials_are_not_echoed
    path = File.join(@directory, 'key.json')
    File.write(path, '{"private_key": "do-not-log-this" invalid}')
    error = assert_raises(RuntimeError) { DevRelease.read_json(path) }
    refute_includes error.message, 'do-not-log-this'
  end

  def test_resume_does_not_repeat_store_upload_when_sentry_failed
    path = File.join(@directory, 'status.json')
    state = {}
    uploads = 0
    DevRelease.step(state, path, 'store_uploaded') { uploads += 1 }
    assert_raises(RuntimeError) { DevRelease.step(state, path, 'sentry_uploaded') { raise 'network' } }
    saved = DevRelease.read_json(path)
    DevRelease.step(saved, path, 'store_uploaded') { uploads += 1 }
    DevRelease.step(saved, path, 'sentry_uploaded') { true }
    assert_equal 1, uploads
    assert_equal({ 'store_uploaded' => true, 'sentry_uploaded' => true }, DevRelease.read_json(path))
  end

  def test_changed_artifact_is_rejected_on_resume
    path = File.join(@directory, 'app.aab')
    File.write(path, 'original signed bundle')
    state = { 'sha256' => Digest::SHA256.file(path).hexdigest }
    DevRelease.verify_artifact(state, path)
    File.write(path, 'different build')
    assert_raises(RuntimeError) { DevRelease.verify_artifact(state, path) }
  end

  def test_command_rejects_prod_before_touching_any_release_state
    wrapper = File.expand_path('../scripts/release', __dir__)
    assert system(wrapper, 'android', 'prod', out: File::NULL, err: File::NULL) == false
  end

  def test_error_response_retains_reason_but_redacts_credentials
    previous = ENV['SENTRY_AUTH_TOKEN']
    ENV['SENTRY_AUTH_TOKEN'] = 'private-test-token'
    response = DevRelease.safe_error("Upload 403: private-test-token; Bearer eyToken.value; permission denied")
    assert_includes response, '403'
    assert_includes response, 'permission denied'
    refute_includes response, 'private-test-token'
    refute_includes response, 'eyToken.value'
  ensure
    ENV['SENTRY_AUTH_TOKEN'] = previous
  end
end
