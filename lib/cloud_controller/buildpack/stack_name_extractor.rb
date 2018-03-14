module VCAP::CloudController
  module Buildpack
    class StackNameExtractor
      def extract_stack_from_file(bits_file_path)
        # bits_file_path = bits_file_path.path if bits_file_path.respond_to?(:path)
        # Zip::File.open(bits_file_path) do |zip_file|
        #   zip_file.each do |entry|
        #     if entry.name == 'manifest.yml'
        #       raise CloudController::Errors::ApiError.new_from_details('BuildpackManifestTooLarge') if entry.size > ONE_MEGABYTE
        #       return YAML.safe_load(entry.get_input_stream.read).dig('stack')
        #     end
        #   end
        # end
        # nil
      end

    end
  end
end
