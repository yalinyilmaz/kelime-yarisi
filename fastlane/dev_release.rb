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

  def self.version(path, requested: '', bump: false)
    source = File.read(path)
    match = VERSION.match(source) or raise 'pubspec.yaml version alanı X.Y.Z+N olmalı.'
    name = requested.empty? ? match[2] : requested
    raise 'Sürüm X.Y.Z olmalı.' unless /\A(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\z/.match?(name)
    raise 'Pazarlama sürümü geriye alınamaz.' if (name.split('.').map(&:to_i) <=> match[2].split('.').map(&:to_i)) == -1
    build = match[3].to_i + (bump ? 1 : 0)
    raise 'Build numarası 1..2100000000 aralığında olmalı.' unless (1..2_100_000_000).cover?(build)
    value = "#{name}+#{build}"
    if bump
      temporary = "#{path}.release-tmp"
      begin
        File.write(temporary, source.sub(VERSION) { "#{Regexp.last_match(1)}#{value}#{Regexp.last_match(4)}" })
        File.rename(temporary, path)
      ensure
        FileUtils.rm_f(temporary)
      end
    end
    [name, build.to_s]
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
