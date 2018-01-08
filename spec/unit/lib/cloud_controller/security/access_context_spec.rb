require 'spec_helper'
require 'cloud_controller/security/access_context'

module VCAP::CloudController
  module Security
    RSpec.describe AccessContext do
      let(:security_context) { spy(VCAP::CloudController::SecurityContext) }
      let(:user) { spy(VCAP::CloudController::User) }
      let(:space) { spy(VCAP::CloudController::Space) }

      subject { AccessContext.new(security_context) }

      before(:each) do
        allow(security_context).to receive(:current_user).and_return(user)
      end

      describe '#is_authenticated?' do
        it 'returns true if the user is authenticated' do
          allow(security_context).to receive(:is_authenticated?).and_return(true)

          is_authenticated = subject.is_authenticated?

          expect(is_authenticated).to equal(true)
        end

        it 'returns false otherwise' do
          allow(security_context).to receive(:is_authenticated?).and_return(false)

          is_authenticated = subject.is_authenticated?

          expect(is_authenticated).to equal(false)
        end
      end

      describe '#can_view_resources?' do
        it 'returns true if the user is an admin' do
          allow(security_context).to receive(:admin?).and_return(true)
          allow(security_context).to receive(:scopes).and_return([])

          can_view_resources = subject.can_view_resources?

          expect(can_view_resources).to equal(true)
        end

        it 'returns true if the user has the read scope' do
          allow(security_context).to receive(:admin?).and_return(false)
          allow(security_context).to receive(:scopes).and_return(['cloud_controller.read'])

          can_view_resources = subject.can_view_resources?

          expect(can_view_resources).to equal(true)
        end

        it 'returns false otherwise' do
          allow(security_context).to receive(:admin?).and_return(false)
          allow(security_context).to receive(:scopes).and_return(['cloud_controller.write'])

          can_view_resources = subject.can_view_resources?

          expect(can_view_resources).to equal(false)
        end
      end

      describe '#can_write_globally?' do
        it 'returns true if the user is an admin' do
          allow(security_context).to receive(:admin?).and_return(true)

          can_write_globally = subject.can_write_globally?

          expect(can_write_globally).to equal(true)
        end

        it 'returns false if the user is a read-only admin' do
          allow(security_context).to receive(:admin?).and_return(false)
          allow(security_context).to receive(:admin_read_only?).and_return(true)

          can_write_globally = subject.can_write_globally?

          expect(can_write_globally).to equal(false)
        end

        it 'returns false if the user is a global auditor' do
          allow(security_context).to receive(:admin?).and_return(false)
          allow(security_context).to receive(:global_auditor?).and_return(true)

          can_write_globally = subject.can_write_globally?

          expect(can_write_globally).to equal(false)
        end

        it 'returns false if the user is not an admin' do
          allow(security_context).to receive(:admin?).and_return(false)

          can_write_globally = subject.can_write_globally?

          expect(can_write_globally).to equal(false)
        end
      end

      describe '#can_write_to_space?' do
        it 'returns true if the user is a space-developer for the space' do
          allow(space).to receive(:has_developer?).with(user).and_return(true)

          can_write_to_space = subject.can_write_to_space?(space)

          expect(can_write_to_space).to equal(true)
        end

        it 'returns false otherwise' do
          allow(space).to receive(:has_developer?).with(user).and_return(false)

          can_write_to_space = subject.can_write_to_space?(space)

          expect(can_write_to_space).to equal(false)
        end
      end
    end
  end
end
