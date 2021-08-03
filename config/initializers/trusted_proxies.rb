module Rack
  class Request

    module Helpers

      def trusted_proxy?(ip)
        ip =~ /^127\.0\.0\.1$|^localhost$|^unix$$/i
      end

    end

  end
end
