require 'vcap/digester'

module VCAP::CloudController
  class UploadBuildpack
    attr_reader :buildpack_blobstore

    def initialize(blobstore)
      @buildpack_blobstore = blobstore
    end

    def upload_buildpack(buildpack, bits_file_path, new_filename)
      return false if buildpack.locked

      sha256 = Digester.new(algorithm: Digest::SHA256).digest_path(bits_file_path)
      new_key = "#{buildpack.guid}_#{sha256}"
      missing_bits = buildpack.key && !buildpack_blobstore.exists?(buildpack.key)

      return false if !new_bits?(buildpack, new_key) && !new_filename?(buildpack, new_filename) && !missing_bits

      # replace blob if new
      if missing_bits || new_bits?(buildpack, new_key)
        buildpack_blobstore.cp_to_blobstore(bits_file_path, new_key)
      end

      old_buildpack_key = nil

      new_stack = extract_stack_from_buildpack(bits_file_path) || Stack.default.name

      begin
        Buildpack.db.transaction do
          buildpack.lock!
          old_buildpack_key = buildpack.key
          buildpack.update(
            key: new_key,
            filename: new_filename,
            sha256_checksum: sha256,
            stack: new_stack,
          )
        end
      rescue Sequel::Error
        BuildpackBitsDelete.delete_when_safe(new_key, 0)
        return false
      end

      if !missing_bits && old_buildpack_key && new_bits?(buildpack, old_buildpack_key)
        staging_timeout = VCAP::CloudController::Config.config.get(:staging, :timeout_in_seconds)
        BuildpackBitsDelete.delete_when_safe(old_buildpack_key, staging_timeout)
      end

      true
    end

    private

    def new_bits?(buildpack, key)
      buildpack.key != key
    end

    def new_filename?(buildpack, filename)
      buildpack.filename != filename
    end

    def extract_stack_from_buildpack(bits_file_path)
      bits_file_path = bits_file_path.path if bits_file_path.respond_to?(:path)
      output, _, status = Open3.capture3('unzip', '-p', bits_file_path, 'manifest.yml')
      YAML.load(output).dig('stack') if status.success?
    end
  end
end
