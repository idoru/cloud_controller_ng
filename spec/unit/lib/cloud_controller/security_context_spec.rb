require 'spec_helper'
require 'cloud_controller/security_context'

module VCAP::CloudController
  RSpec.describe SecurityContext do
    let(:user) { VCAP::CloudController::User.make }
    let(:roles) { VCAP::CloudController::Roles.make }

    subject { SecurityContext }

    describe '#is_authenticated?' do
      it 'returns true if there is a current user' do
        set_current_user(user, scopes: [])

        is_authenticated = subject.is_authenticated?

        expect(is_authenticated).to equal(true)
      end

      it 'returns true if there are any scope-based roles' do
        token = {
          'scope' => ['cloud_controller.read'],
        }
        set_current_user(nil, { token: token })

        is_authenticated = subject.is_authenticated?

        expect(is_authenticated).to equal(true)
      end

      it 'returns false if there is neither a current user nor any roles' do
        set_current_user(nil, scopes: [])

        is_authenticated = subject.is_authenticated?

        expect(is_authenticated).to equal(false)
      end
    end
  end
end
