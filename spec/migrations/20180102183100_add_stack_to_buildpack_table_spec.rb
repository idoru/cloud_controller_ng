require 'spec_helper'

RSpec.describe 'Adding multiple stack support to buildpack model', isolation: :truncation do
  let(:start_event_created_at) { Time.new(2017, 1, 1) }
  let(:migrations_dir) { File.expand_path(File.join(File.dirname(__FILE__), '../../db/migrations')) }
  let(:pre_down_migration_stack) { VCAP::CloudController::Stack.make }

  before do
    VCAP::CloudController::Buildpack.make(name: 'a-great-buildpack-really', stack: pre_down_migration_stack.name)
    Sequel::Migrator.run(VCAP::CloudController::Buildpack.db, migrations_dir, target: 20171220183100)
  end

  after do
    Sequel::Migrator.run(VCAP::CloudController::Buildpack.db, migrations_dir)
  end

  context 'STACKS_YML set to filepath specifying default stack' do
    let!(:original_env) { ENV["STACKS_YML"] }
    let(:stacks_yml_path) { File.expand_path(File.join(File.dirname(__FILE__), '../fixtures/config/stacks.yml')) }

    before { ENV["STACKS_YML"] = stacks_yml_path }
    after { ENV["STACKS_YML"] = original_env }

    it 'assigns the default stack to existing buildpacks' do
      Sequel::Migrator.run(VCAP::CloudController::Buildpack.db, migrations_dir, target: 20180102183100)
      expect(VCAP::CloudController::Buildpack.where(name: 'a-great-buildpack-really', stack: 'default-stack-name').count).to eq(1)
    end
  end

  context 'STACKS_YML not set' do
    it 'assigns the default stack to existing buildpacks' do
      Sequel::Migrator.run(VCAP::CloudController::Buildpack.db, migrations_dir, target: 20180102183100)
      expect(VCAP::CloudController::Buildpack.where(name: 'a-great-buildpack-really', stack: nil).count).to eq(1)
    end
  end
end
