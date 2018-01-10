require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe BuildpackPresenter do
    let(:buildpack_presenter) { BuildpackPresenter.new }
    let(:controller) { 'controller' }
    let(:opts) { {} }
    let(:depth) { 0 }
    let(:parents) { 'parents' }
    let(:orphans) { 'orphans' }
    let(:relations_presenter) { instance_double(RelationsPresenter, to_hash: relations_hash) }
    let(:relations_hash) { {} }
    before do
      allow(RelationsPresenter).to receive(:new).and_return(relations_presenter)
    end

    describe '#entity_hash' do
      let(:buildpack) { VCAP::CloudController::Buildpack.make() }

      it 'returns the space entity and associated urls' do
        expected_entity_hash = {
          'name' => buildpack.name,
          'stack' => buildpack.stack,
          'enabled' => buildpack.enabled,
          'locked' => buildpack.locked,
          'position' => buildpack.position,
          'filename' => "#{buildpack.filename} (#{buildpack.stack})",
        }

        actual_entity_hash = buildpack_presenter.entity_hash(controller, buildpack, opts, depth, parents, orphans)

        expect(actual_entity_hash).to be_a_response_like(expected_entity_hash)
      end
    end
  end
end
