module VCAP::CloudController
  module Security
    class AccessContext
      include ::Allowy::Context

      def initialize(security_context)
        @security_context = security_context
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

      private

      attr_reader :security_context
    end
  end
end
