# frozen_string_literal: true

require "rails_helper"

describe Postal::DKIMHeader do
  examples = Rails.root.join("spec/examples/dkim_signing/*.msg")
  Dir[examples].each do |path|
    contents = File.read(path)
    frontmatter, email = contents.split(/^---\n/m, 2)
    frontmatter = YAML.load(frontmatter)
    email.strip
    it "works with #{path.split('/').last}" do
      mocked_time = Time.at(frontmatter["time"].to_i)
      allow(Time).to receive(:now).and_return(mocked_time)

      domain = instance_double("Domain")
      allow(domain).to receive(:dkim_status).and_return("OK")
      allow(domain).to receive(:name).and_return(frontmatter["domain"])
      allow(domain).to receive(:dkim_key).and_return(OpenSSL::PKey::RSA.new(frontmatter["private_key"]))
      allow(domain).to receive(:dkim_identifier).and_return(frontmatter["dkim_identifier"])

      expectation = "DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed;\r\n"  \
                    "\td=#{frontmatter['domain']};\r\n" \
                    "\ts=#{frontmatter['dkim_identifier']}; t=#{mocked_time.to_i};\r\n" \
                    "\tbh=#{frontmatter['bh']};\r\n"\
                    "\th=#{frontmatter['headers']};\r\n" \
                    "\tb=#{frontmatter['b'].scan(/.{1,72}/).join("\r\n\t")}"

      header = described_class.new(domain, email)

      expect(header.dkim_header).to eq expectation
    end
  end
end
