module CloudController
  module Presenters
    module V2
      class BuildpackPresenter < DefaultPresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::Buildpack'

        def entity_hash(controller, buildpack, opts, depth, parents, orphans=nil)
          entity = super
          entity['filename'] = "#{buildpack.filename} (#{buildpack.stack})"
          entity
        end
      end
    end
  end
end
