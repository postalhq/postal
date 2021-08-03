module Postal
  module Helpers

    def self.strip_name_from_address(address)
      return nil if address.nil?

      address.gsub(/.*</, "").gsub(/>.*/, "").gsub(/\(.+?\)/, "").strip
    end

  end
end
