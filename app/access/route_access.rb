module VCAP::CloudController
  class RouteAccess < BaseAccess
    def create?(route, params=nil)
      return true if context.can_write_globally?
      return false if route.in_suspended_org?
      return false if route.host == '*' && route.domain.shared?
      FeatureFlag.raise_unless_enabled!(:route_creation)
      context.can_write_to_space?(route.space)
    end

    def read_for_update?(route, params=nil)
      update?(route, params)
    end

    def update?(route, params=nil)
      return true if context.can_write_globally?
      return false if route.in_suspended_org?
      return false if route.host == '*' && route.domain.shared?
      context.can_write_to_space?(route.space)
    end

    def delete?(route)
      update?(route)
    end

    def reserved?(_)
      context.is_authenticated?
    end

    def reserved_with_token?(_)
      context.can_view_resources?
    end
  end
end
