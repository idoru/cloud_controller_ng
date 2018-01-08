require 'spec_helper'

module VCAP::CloudController
  RSpec.describe StackAccess, type: :access do
    let(:access_context) { Security::AccessContext.new(VCAP::CloudController::SecurityContext) }
    subject(:access) { StackAccess.new(access_context) }
    let(:user) { VCAP::CloudController::User.make }
    let(:object) { VCAP::CloudController::Stack.make }

    before { set_current_user(user) }

    it_behaves_like :admin_full_access
    it_behaves_like :admin_read_only_access

    context 'a logged in user' do
      it_behaves_like :read_only_access
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }

      it_behaves_like :no_access
    end

    context 'any user using client without cloud_controller.read' do
      before { set_current_user(user, scopes: []) }

      it_behaves_like :no_access
    end
  end
end
