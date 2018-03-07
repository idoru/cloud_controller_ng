module VCAP::CloudController
  module Jobs
    module Runtime
      class BuildpackInstaller < VCAP::CloudController::Jobs::CCJob
        attr_accessor :name, :file, :opts

        def initialize(name, file, opts)
          @name = name
          @file = file
          @opts = opts
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info "Installing buildpack #{name}"

          buildpacks = find_existing_buildpacks
          buildpack = nil
          if buildpacks.empty?
            buildpacks_lock = Locking[name: 'buildpacks']
            buildpacks_lock.db.transaction do
              buildpacks_lock.lock!
              buildpack = Buildpack.create(name: name, stack: 'unknown')
            end
            created = true
          elsif buildpacks.count > 1
            logger.error "Update failed: Unable to determine buildpack to update as there are multiple buildpacks named #{name} for different stacks."
            return
          elsif buildpacks.first.locked
            logger.info "Buildpack #{name} locked, not updated"
            return
          else
            buildpack = buildpacks.first
          end

          begin
            buildpack_uploader.upload_buildpack(buildpack, file, File.basename(file))
          rescue => e
            if created
              buildpack.destroy
            end
            raise e
          end

          buildpack.update(opts)
          logger.info "Buildpack #{name} installed or updated"
        rescue => e
          logger.error("Buildpack #{name} failed to install or update. Error: #{e.inspect}")
          raise e
        end

        def max_attempts
          1
        end

        def job_name_in_configuration
          :buildpack_installer
        end

        def buildpack_uploader
          buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
          UploadBuildpack.new(buildpack_blobstore)
        end

        private

        def find_existing_buildpacks
          stack = buildpack_uploader.extract_stack_from_buildpack(file)
          return Buildpack.where(name: name, stack: stack) if stack.present?

          Buildpack.where(name: name)
        end
      end
    end
  end
end
