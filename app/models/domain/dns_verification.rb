require "resolv"

class Domain

  def dns_verification_string
    "#{Postal.config.dns.domain_verify_prefix} #{verification_token}"
  end

  def verify_with_dns
    return false unless verification_method == "DNS"

    result = resolver.getresources(name, Resolv::DNS::Resource::IN::TXT)
    if result.map { |d| d.data.to_s.strip }.include?(dns_verification_string)
      self.verified_at = Time.now
      save
    else
      false
    end
  end

end

# -*- SkipSchemaAnnotations
