module VCAP::CloudController
  class BuildpackLifecycleFetcher
    class << self
      def fetch(buildpack_names, stack_name)
        {
          stack: Stack.find(name: stack_name),
          buildpack_infos: ordered_buildpacks(buildpack_names, stack_name),
        }
      end

      private

      ## NOTE: if a requested system buildpack is not on the requested stack,
      ##       the BuildpackInfo object will have a name and not a record (even
      ##       though the buildpack exists). At this point the error returned
      ##       to the user will probably be VERY confusing

      ## XTEAM: Add a separate story to maybe have a helpful error here?

      def ordered_buildpacks(buildpack_names, stack_name)
        buildpacks = Buildpack.list_admin_buildpacks(stack_name)

        buildpack_names.map do |buildpack_name|
          exact_match = buildpacks.find { |b| b.name == buildpack_name && b.stack == stack_name }
          name_match = buildpacks.find { |b| b.name == buildpack_name }

          buildpack_record = exact_match || name_match

          BuildpackInfo.new(buildpack_name, buildpack_record)
        end
      end
    end
  end
end
