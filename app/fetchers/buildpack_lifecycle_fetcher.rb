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

      def ordered_buildpacks(buildpack_names, stack_name)
        buildpacks = Buildpack.where(name: buildpack_names, stack: stack_name).all #[]
        # Given that some of these buildpacks have nil stack
        # Return buildpacks that have nil stacks
        # Except don't return them if they are a duplicate name of a buildpack that has a stack, and matching the stack_name

        buildpack_names.map do |buildpack_name|
          buildpack_record = buildpacks.find { |b| b.name == buildpack_name }
          BuildpackInfo.new(buildpack_name, buildpack_record)
        end
      end
    end
  end
end
