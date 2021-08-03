module Postal
  class MXLookup

    class << self

      def lookup(domain)
        records = resolve(domain)
        records = sort(records)
        records.map { |m| m[1] }
      end

      private

      def sort(records)
        records.sort do |a, b|
          if a[0] == b[0]
            [-1, 1].sample
          else
            a[0] <=> b[0]
          end
        end
      end

      def resolve(domain)
        Resolv::DNS.open do |dns|
          dns.timeouts = [10, 5]
          dns.getresources(domain, Resolv::DNS::Resource::IN::MX).map { |m| [m.preference.to_i, m.exchange.to_s] }
        end
      end

    end

  end
end
