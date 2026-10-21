require 'minitest/autorun'
require 'tmpdir'
require_relative '../fastlane/dev_release'

class DevReleaseTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir('ky-release-test-')
    @pubspec = File.join(@directory, 'pubspec.yaml')
    @version_path = File.join(@directory, '.local/releases/dev/version.json')
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
    version = DevRelease.version(@pubspec, bump: true, state_path: @version_path)
    assert_equal ['0.1.0', '42'], version
    DevRelease.save_version(@version_path, *version)
    assert_equal @source, File.read(@pubspec)
    assert_equal ['0.1.0', '42'], DevRelease.version(@pubspec, state_path: @version_path)
    assert_equal ['0.1.0', '43'], DevRelease.version(@pubspec, bump: true, state_path: @version_path)
  end

  def test_marketing_version_still_increments_build
    version = DevRelease.version(@pubspec, requested: '1.2.3', bump: true, state_path: @version_path)
    assert_equal ['1.2.3', '42'], version
    DevRelease.save_version(@version_path, *version)
    assert_equal ['1.2.3', '42'], DevRelease.version(@pubspec, state_path: @version_path)
    assert_equal @source, File.read(@pubspec)
  end

  def test_failed_build_does_not_change_source_or_local_counter
    planned = DevRelease.version(@pubspec, requested: '0.2.0', bump: true, state_path: @version_path)
    assert_equal ['0.2.0', '42'], planned
    assert_equal @source, File.read(@pubspec)
    assert_equal planned, DevRelease.version(@pubspec, requested: '0.2.0', bump: true, state_path: @version_path)
    refute File.exist?(@version_path)
  end

  def test_existing_uploaded_build_survives_pubspec_discard
    File.write(@pubspec, @source.sub('0.1.0+41', '0.1.0+1'))
    DevRelease.save_version(@version_path, '0.1.0', '5')
    assert_equal ['0.1.0', '5'], DevRelease.version(@pubspec, state_path: @version_path)
    assert_equal ['0.1.0', '6'], DevRelease.version(@pubspec, bump: true, state_path: @version_path)
  end

  def test_local_marketing_version_cannot_be_downgraded
    DevRelease.save_version(@version_path, '0.2.0', '50')
    assert_raises(RuntimeError) { DevRelease.version(@pubspec, requested: '0.1.1', state_path: @version_path) }
    assert_equal ['0.2.0', '51'], DevRelease.version(@pubspec, bump: true, state_path: @version_path)
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

  def test_failed_build_can_retry_same_unpublished_version
    directory = File.join(@directory, 'android')
    previous = DevRelease.new_build_state(directory, '0.1.0+42', 'android')
    File.write(File.join(directory, 'partial.symbols'), 'incomplete')
    retried = DevRelease.new_build_state(directory, '0.1.0+42', 'android')
    refute_equal previous['proguard_uuid'], retried['proguard_uuid']
    refute File.exist?(File.join(directory, 'partial.symbols'))
    assert_equal '0.1.0+42', retried['version']
  end

  def test_completed_build_is_never_overwritten_by_retry
    directory = File.join(@directory, 'android')
    state = DevRelease.new_build_state(directory, '0.1.0+42', 'android')
    state['built'] = true
    DevRelease.write_json(File.join(directory, 'status.json'), state)
    artifact = File.join(directory, 'app.aab')
    File.write(artifact, 'signed bundle')
    assert_raises(RuntimeError) { DevRelease.new_build_state(directory, '0.1.0+42', 'android') }
    assert_equal 'signed bundle', File.read(artifact)
  end

  def test_command_rejects_prod_before_touching_any_release_state
    wrapper = File.expand_path('../scripts/release', __dir__)
    assert system(wrapper, 'android', 'prod', out: File::NULL, err: File::NULL) == false
  end

  def test_app_distribution_cannot_be_selected_for_android_or_all
    wrapper = File.expand_path('../scripts/release', __dir__)
    %w[android all].each do |target|
      refute system(wrapper, target, 'dev', '--app-distribution', out: File::NULL, err: File::NULL)
    end
    assert_equal 'testflight', DevRelease.destination('ios')
    assert_equal 'play-internal', DevRelease.destination('android')
    assert_equal 'app-distribution', DevRelease.destination('ios', app_distribution: true)
  end

  def test_resume_never_switches_distribution_or_reuses_legacy_testflight_ipa
    legacy = { 'platform' => 'ios', 'built' => true, 'store_uploaded' => true }
    DevRelease.verify_destination(legacy, 'testflight')
    assert_raises(RuntimeError) { DevRelease.verify_destination(legacy, 'app-distribution') }
    ad_hoc = legacy.merge('destination' => 'app-distribution', 'app_distribution_uploaded' => true)
    DevRelease.verify_destination(ad_hoc, 'app-distribution')
    assert_raises(RuntimeError) { DevRelease.verify_destination(ad_hoc, 'testflight') }
  end

  def test_ad_hoc_cleanup_requires_firebase_upload_even_if_store_flag_is_set
    directory, state = release_fixture('ios')
    state['destination'] = 'app-distribution'
    DevRelease.write_json(File.join(directory, 'status.json'), state)
    assert_raises(RuntimeError) { DevRelease.cleanup_release(@directory, directory) }
    assert File.exist?(File.join(directory, 'KelimeYarisiDev.ipa'))
    state['app_distribution_uploaded'] = true
    DevRelease.write_json(File.join(directory, 'status.json'), state)
    assert_operator DevRelease.cleanup_release(@directory, directory), :>, 0
    assert_equal ['status.json'], Dir.children(directory)
  end

  def test_xcode_temporary_exports_stay_in_release_and_restore_tmpdir_on_failure
    previous = ENV['TMPDIR']
    assert_raises(RuntimeError) do
      DevRelease.with_release_tmpdir(@directory) do
        assert_equal File.join(@directory, 'tmp'), ENV['TMPDIR']
        assert Dir.exist?(ENV['TMPDIR'])
        raise 'export failed'
      end
    end
    assert_equal previous, ENV['TMPDIR']
  end

  def test_app_distribution_upload_is_pinned_to_dev_and_passes_testers_by_file
    arguments = DevRelease.app_distribution_arguments('/private/build.ipa', '/private/testers.txt', '0.1.0+42')
    assert_equal 'kelime-yarisi-yalin', arguments[arguments.index('--project') + 1]
    assert_equal '1:173227658652:ios:c6e3ba382101755e004c59', arguments[arguments.index('--app') + 1]
    assert_includes arguments, '--testers-file'
    refute_includes arguments, '--token'
    refute_includes arguments, '--testers'
  end

  def test_ad_hoc_profile_rejects_app_store_debug_wrong_bundle_and_wrong_team
    profile = {
      'ProvisionedDevices' => ['registered-test-device'],
      'Entitlements' => {
        'application-identifier' => 'TEAM123.com.yalinyilmaz.kelimeYarisi.dev',
        'get-task-allow' => false,
        'com.apple.developer.devicecheck.appattest-environment' => %w[development production]
      }
    }
    assert_equal 1, DevRelease.verify_ad_hoc_profile(profile, 'TEAM123')
    assert_raises(RuntimeError) { DevRelease.verify_ad_hoc_profile(profile.reject { |k, _| k == 'ProvisionedDevices' }, 'TEAM123') }
    assert_raises(RuntimeError) { DevRelease.verify_ad_hoc_profile(profile.merge('ProvisionsAllDevices' => true), 'TEAM123') }
    assert_raises(RuntimeError) { DevRelease.verify_ad_hoc_profile(profile, 'OTHERTEAM') }
    %w[get-task-allow application-identifier com.apple.developer.devicecheck.appattest-environment].each do |key|
      invalid = profile.merge('Entitlements' => profile['Entitlements'].merge(key => 'invalid'))
      assert_raises(RuntimeError) { DevRelease.verify_ad_hoc_profile(invalid, 'TEAM123') }
    end
  end

  def test_error_response_retains_reason_but_redacts_credentials
    previous = ENV['SENTRY_AUTH_TOKEN']
    ENV['SENTRY_AUTH_TOKEN'] = 'private-test-token'
    response = DevRelease.safe_error("Upload 403: private-test-token; Bearer eyToken.value; permission denied")
    assert_includes response, '403'
    assert_includes response, 'permission denied'
    refute_includes response, 'private-test-token'
    refute_includes response, 'eyToken.value'
    google_response = DevRelease.safe_error('Firebase failed: ya29.example-access-token 1//example-refresh-token')
    refute_includes google_response, 'ya29.example-access-token'
    refute_includes google_response, '1//example-refresh-token'
  ensure
    ENV['SENTRY_AUTH_TOKEN'] = previous
  end

  def release_fixture(platform = 'android')
    directory = File.join(@directory, '.local/releases/dev/0.1.0+42', platform)
    state = DevRelease.new_build_state(directory, '0.1.0+42', platform)
    state.merge!('built' => true, 'store_uploaded' => true, 'sentry_uploaded' => true)
    package_name = platform == 'android' ? 'app-dev-release.aab' : 'KelimeYarisiDev.ipa'
    File.write(File.join(directory, package_name), 'signed package')
    state['sha256'] = Digest::SHA256.hexdigest('signed package')
    DevRelease.write_json(File.join(directory, 'status.json'), state)
    [directory, state]
  end

  def test_cleanup_requires_both_uploads_and_preserves_retry_files
    directory, state = release_fixture
    state['sentry_uploaded'] = false
    DevRelease.write_json(File.join(directory, 'status.json'), state)
    assert_raises(RuntimeError) { DevRelease.cleanup_release(@directory, directory) }
    assert File.exist?(File.join(directory, 'app-dev-release.aab'))
  end

  def test_cleanup_removes_uploaded_package_and_only_owned_android_outputs
    directory, state = release_fixture
    FileUtils.mkdir_p(File.join(directory, 'symbols'))
    File.write(File.join(directory, 'symbols/app.android-arm64.symbols'), 'symbols')
    generated = File.join(@directory, 'build/app/outputs/bundle/devRelease/app-dev-release.aab')
    FileUtils.mkdir_p(File.dirname(generated))
    File.write(generated, 'signed package')
    debug = File.join(@directory, 'build/app/intermediates/flutter/devDebug/app.so')
    ios = File.join(@directory, 'build/ios/iphoneos/Runner.app/Runner')
    credential = File.join(@directory, '.local/credentials/upload.jks')
    [debug, ios, credential].each do |path|
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, 'keep')
    end
    own_cache = File.join(@directory, '.dart_tool/flutter_build', 'a' * 32)
    other_cache = File.join(@directory, '.dart_tool/flutter_build', 'b' * 32)
    [own_cache, other_cache].each do |path|
      FileUtils.mkdir_p(path)
      File.write(File.join(path, 'android_aot_release_android-arm64.stamp'), '{}')
    end
    state['flutter_build_caches'] = [File.basename(own_cache)]
    DevRelease.write_json(File.join(directory, 'status.json'), state)
    assert_operator DevRelease.cleanup_release(@directory, directory), :>, 0
    assert_equal ['status.json'], Dir.children(directory)
    refute File.exist?(generated)
    refute Dir.exist?(own_cache)
    assert Dir.exist?(other_cache)
    [debug, ios, credential].each { |path| assert_equal 'keep', File.read(path) }
    assert DevRelease.read_json(File.join(directory, 'status.json'))['cleaned']
  end

  def test_cleanup_keeps_a_newer_android_build
    directory, state = release_fixture
    generated = File.join(@directory, 'build/app/outputs/bundle/devRelease/app-dev-release.aab')
    FileUtils.mkdir_p(File.dirname(generated))
    File.write(generated, 'different newer build')
    DevRelease.cleanup_release(@directory, directory)
    assert_equal 'different newer build', File.read(generated)
  end

  def test_cleanup_ios_removes_own_archive_but_preserves_runner_and_keys
    directory, state = release_fixture('ios')
    %w[Runner.xcarchive DerivedData symbols].each do |name|
      FileUtils.mkdir_p(File.join(directory, name))
      File.write(File.join(directory, name, 'temporary'), 'temporary')
    end
    runner = File.join(@directory, 'build/ios/iphoneos/Runner.app/Runner')
    FileUtils.mkdir_p(File.dirname(runner))
    File.write(runner, 'keep Runner.app')
    assert_operator DevRelease.cleanup_release(@directory, directory), :>, 0
    assert_equal ['status.json'], Dir.children(directory)
    assert_equal 'keep Runner.app', File.read(runner)
  end

  def test_cleanup_rejects_directory_outside_release_root
    directory, state = release_fixture
    outside = File.join(@directory, 'some-other-folder')
    FileUtils.mkdir_p(outside)
    DevRelease.write_json(File.join(outside, 'status.json'), state)
    File.write(File.join(outside, 'keep'), 'keep')
    assert_raises(RuntimeError) { DevRelease.cleanup_release(@directory, outside) }
    assert_equal 'keep', File.read(File.join(outside, 'keep'))
  end
end
