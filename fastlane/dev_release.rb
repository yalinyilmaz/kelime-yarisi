require 'json'
require 'fileutils'
require 'securerandom'
require 'shellwords'
require 'digest'

module DevRelease
  class << self
    attr_accessor :current_step
  end

  IDS = {
    'android' => 'com.yalinyilmaz.kelime_yarisi.dev',
    'ios' => 'com.yalinyilmaz.kelimeYarisi.dev'
  }.freeze
  VERSION = /^(version:\s*)(\d+\.\d+\.\d+)\+(\d+)(\s*(?:#.*)?)$/
  ENV_KEYS = %w[ANDROID_KEYSTORE_PATH ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS
                ANDROID_KEY_PASSWORD PLAY_JSON_KEY_PATH APPLE_TEAM_ID ASC_KEY_ID
                ASC_ISSUER_ID ASC_KEY_PATH SENTRY_ORG SENTRY_PROJECT SENTRY_AUTH_TOKEN].freeze

  def self.version(path, requested: '', bump: false, state_path: nil)
    match = VERSION.match(File.read(path)) or raise 'pubspec.yaml version alanı X.Y.Z+N olmalı.'
    saved = state_path && File.file?(state_path) ? read_json(state_path) : { 'name' => match[2], 'build' => match[3] }
    saved_name = saved.fetch('name')
    saved_build = saved.fetch('build').to_s
    raise 'Yerel build sayacı geçersiz.' unless saved_build.match?(/\A[1-9]\d*\z/)
    names = [match[2], saved_name]
    names << requested unless requested.empty?
    unless names.all? { |name| name.is_a?(String) && /\A(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\z/.match?(name) }
      raise 'Sürüm X.Y.Z olmalı.'
    end
    floor_name = names.first(2).max_by { |name| name.split('.').map(&:to_i) }
    name = requested.empty? ? floor_name : requested
    raise 'Pazarlama sürümü geriye alınamaz.' if (name.split('.').map(&:to_i) <=> floor_name.split('.').map(&:to_i)) == -1
    build = [match[3].to_i, saved_build.to_i].max + (bump ? 1 : 0)
    raise 'Build numarası 1..2100000000 aralığında olmalı.' unless (1..2_100_000_000).cover?(build)
    [name, build.to_s]
  end

  def self.save_version(path, name, build)
    write_json(path, 'name' => name, 'build' => build)
  end

  def self.defines(dsn_file, release, build, uuid = nil)
    dsn = read_json(dsn_file)
    raise 'sentry.dev.json yalnız SENTRY_DSN içerebilir; upload anahtarlarını çıkar.' unless dsn.keys == ['SENTRY_DSN']
    raise 'Dev SENTRY_DSN eksik/geçersiz.' unless dsn['SENTRY_DSN'].is_a?(String) && dsn['SENTRY_DSN'].start_with?('https://')
    dsn.merge('SENTRY_RELEASE' => release, 'SENTRY_DIST' => build,
              'QUESTION_POOL_ENABLED' => 'true').tap do |result|
      result['SENTRY_PROGUARD_UUID'] = uuid if uuid
    end
  end

  def self.path(root, value)
    File.expand_path(value, root)
  end

  def self.safe_error(message)
    result = message.to_s.dup
    %w[ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_PASSWORD SENTRY_AUTH_TOKEN].each do |key|
      secret = ENV[key].to_s
      result.gsub!(secret, '[REDACTED]') unless secret.empty?
    end
    result.gsub!(/-----BEGIN[^\n]*PRIVATE KEY-----.*?-----END[^\n]*PRIVATE KEY-----/m, '[REDACTED PRIVATE KEY]')
    result.gsub!(/(Bearer\s+)[A-Za-z0-9._\-]+/i, '\\1[REDACTED]')
    result
  end

  def self.progress(ui, description)
    self.current_step = description
    ui.header("⏳ #{description}")
  end

  def self.require_env(*keys)
    missing = keys.select { |key| ENV[key].to_s.strip.empty? }
    raise "Yerel ayarlarda eksik: #{missing.join(', ')}. fastlane/README.md dosyasına bak." unless missing.empty?
  end

  def self.require_file(path)
    raise "Dosya yok: #{path}" unless File.file?(path)
  end

  def self.read_json(path)
    JSON.parse(File.read(path))
  rescue JSON::ParserError
    raise "Geçersiz JSON: #{path}. Dosya içeriği güvenlik nedeniyle gösterilmedi."
  end

  def self.executable(name)
    ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, name)) }
  end

  def self.write_json(path, object)
    FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
    temporary = "#{path}.tmp"
    File.write(temporary, JSON.pretty_generate(object), mode: 'w', perm: 0o600)
    File.rename(temporary, path)
  end

  def self.step(state, path, key)
    return false if state[key]
    yield
    state[key] = true
    write_json(path, state)
    true
  end

  def self.verify_artifact(state, path)
    require_file(path)
    raise 'Paket değişmiş; aynı sürüm için farklı dosya yüklenemez.' unless Digest::SHA256.file(path).hexdigest == state.fetch('sha256')
  end

  def self.new_build_state(directory, version, platform)
    state_path = File.join(directory, 'status.json')
    if File.exist?(state_path)
      previous = read_json(state_path)
      completed = %w[built store_uploaded sentry_uploaded].any? { |key| previous[key] }
      raise "Bu sürümün çıktısı zaten var: #{version}. --resume kullan." if completed
      unless previous['version'] == version && previous['platform'] == platform
        raise 'Önceki build kaydı hedef sürüm/platformla eşleşmiyor; çıktılar korunuyor.'
      end
      # A failed build has never reserved a store version. Clear only its
      # partial output so the unchanged pubspec can be retried safely.
      FileUtils.rm_rf(directory)
    end
    state = { 'version' => version, 'platform' => platform, 'proguard_uuid' => SecureRandom.uuid }
    write_json(state_path, state)
    state
  end

  def self.release_caches(root, platform)
    marker = platform == 'android' ? 'android_aot_release_*.stamp' : 'release_ios_bundle_flutter_assets.stamp'
    Dir.glob(File.join(root, '.dart_tool/flutter_build/*')).select do |directory|
      File.directory?(directory) && !File.symlink?(directory) &&
        File.basename(directory).match?(/\A[0-9a-f]{32}\z/) && !Dir.glob(File.join(directory, marker)).empty?
    end.map { |directory| File.basename(directory) }
  end

  def self.remove_output(path)
    return 0 unless File.exist?(path) || File.symlink?(path)
    bytes = if File.symlink?(path)
              0
            elsif File.directory?(path)
              Dir.glob(File.join(path, '**/*'), File::FNM_DOTMATCH).sum do |file|
                File.file?(file) && !File.symlink?(file) ? File.size(file) : 0
              end
            else
              File.size(path)
            end
    FileUtils.remove_entry(path)
    bytes
  end

  def self.cleanup_release(root, directory)
    state = read_json(File.join(directory, 'status.json'))
    unless state['store_uploaded'] == true && state['sentry_uploaded'] == true
      raise 'Mağaza ve Sentry yüklemesi tamamlanmadı; paket ve semboller korunuyor.'
    end
    platform = state.fetch('platform')
    version = state.fetch('version')
    raise 'Temizleme hedefi geçersiz.' unless IDS.key?(platform) && version.match?(/\A\d+\.\d+\.\d+\+\d+\z/)
    expected = File.join(File.realpath(root), '.local/releases/dev', version, platform)
    raise 'Temizleme yalnız bu dev release dizininde yapılabilir.' unless File.realpath(directory) == expected
    bytes = 0
    if platform == 'android'
      generated = File.join(root, 'build/app/outputs/bundle/devRelease/app-dev-release.aab')
      if File.file?(generated) && Digest::SHA256.file(generated).hexdigest == state['sha256']
        Dir.glob(File.join(root, 'build/app/**/devRelease')).each do |path|
          bytes += remove_output(path) if File.directory?(path) && !File.symlink?(path)
        end
      end
    end
    owned_caches = Array(state['flutter_build_caches']) & release_caches(root, platform)
    owned_caches.each do |name|
      bytes += remove_output(File.join(root, '.dart_tool/flutter_build', name))
    end
    Dir.children(directory).each do |entry|
      bytes += remove_output(File.join(directory, entry)) unless entry == 'status.json'
    end
    state['cleaned'] = true
    state['cleaned_bytes'] = bytes
    state.delete('flutter_build_caches')
    write_json(File.join(directory, 'status.json'), state)
    bytes
  end

  def self.preflight(root, platforms, mode)
    require_env('SENTRY_ORG', 'SENTRY_PROJECT', 'SENTRY_AUTH_TOKEN') unless mode == 'build-only'
    %w[flutter dart].each { |name| raise "Komut yok: #{name}" unless executable(name) }
    raise 'sentry-cli eksik. fastlane/README.md dosyasındaki kurulumu tamamla.' if mode != 'build-only' && !executable('sentry-cli')
    # Do not accept arbitrary dart-defines from the credentials file.
    defines(File.join(root, '.local/sentry.dev.json'), 'check', '1')
    platforms.each do |platform|
      if platform == 'android'
        require_env('ANDROID_KEYSTORE_PATH', 'ANDROID_KEYSTORE_PASSWORD', 'ANDROID_KEY_ALIAS', 'ANDROID_KEY_PASSWORD')
        ENV['ANDROID_KEYSTORE_PATH'] = path(root, ENV.fetch('ANDROID_KEYSTORE_PATH'))
        require_file(ENV['ANDROID_KEYSTORE_PATH'])
        require_file(File.join(root, 'android/app/src/dev/google-services.json'))
        if mode != 'build-only'
          require_env('PLAY_JSON_KEY_PATH')
          ENV['PLAY_JSON_KEY_PATH'] = path(root, ENV.fetch('PLAY_JSON_KEY_PATH'))
          require_file(ENV['PLAY_JSON_KEY_PATH'])
          key = read_json(ENV['PLAY_JSON_KEY_PATH'])
          raise 'Play JSON bir servis hesabı anahtarı olmalı.' unless key['type'] == 'service_account' && key['private_key'] && key['client_email']
        end
      else
        require_env('APPLE_TEAM_ID', 'ASC_KEY_ID', 'ASC_ISSUER_ID', 'ASC_KEY_PATH')
        raise 'iOS release için macOS ve Xcode gerekir.' unless RUBY_PLATFORM.include?('darwin') && executable('xcodebuild')
        ENV['ASC_KEY_PATH'] = path(root, ENV.fetch('ASC_KEY_PATH'))
        require_file(ENV['ASC_KEY_PATH'])
        require_file(File.join(root, 'ios/config/dev/GoogleService-Info.plist'))
      end
    end
  end
end
