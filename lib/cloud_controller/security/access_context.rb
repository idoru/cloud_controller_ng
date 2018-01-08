module VCAP::CloudController
  module Security
    class AccessContext
      include ::Allowy::Context

      READ_SCOPE = 'cloud_controller.read'

      def initialize(security_context)
        @security_context = security_context
        @current_user = security_context.current_user
      end

      def admin_override
        security_context.admin? || security_context.admin_read_only? || security_context.global_auditor?
      end

      def roles
        security_context.roles
      end

      def user_email
        security_context.current_user_email
      end

      def user
        security_context.current_user
      end

      def is_authenticated?
        security_context.is_authenticated?
      end

      def can_view_resources?
        security_context.admin? || security_context.scopes.include?(READ_SCOPE)
      end

      def can_write_globally?
        security_context.admin?
      end

      def can_write_to_space?(space)
        space.has_developer?(current_user)
      end

      private

      attr_reader :security_context, :current_user
    end
  end
end
