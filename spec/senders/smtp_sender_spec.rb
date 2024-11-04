# frozen_string_literal: true

require "rails_helper"

RSpec.describe SMTPSender do
  subject(:sender) { described_class.new("example.com") }

  let(:smtp_start_error) { nil }
  let(:smtp_send_message_error) { nil }
  let(:smtp_send_message_result) { double("Result", string: "accepted") }

  before do
    # Mock the SMTP client endpoint so that we can avoid making any actual
    # SMTP connections but still mock things as appropriate.
    allow(SMTPClient::Endpoint).to receive(:new).and_wrap_original do |original, *args, **kwargs|
      endpoint = original.call(*args, **kwargs)

      allow(endpoint).to receive(:start_smtp_session) do |**ikwargs|
        if error = smtp_start_error&.call(endpoint, ikwargs[:allow_ssl])
          raise error
        end
      end

      allow(endpoint).to receive(:send_message) do |message|
        if error = smtp_send_message_error&.call(endpoint, message)
          raise error
        end

        smtp_send_message_result
      end
      allow(endpoint).to receive(:finish_smtp_session)
      allow(endpoint).to receive(:reset_smtp_session)
      allow(endpoint).to receive(:smtp_client) do
        Net::SMTP.new(endpoint.ip_address, endpoint.server.port)
      end
      endpoint
    end
  end

  before do
    # Override the DNS resolver to return empty arrays by default for A and AAAA
    # DNS lookups to avoid making requests to public servers.
    allow(DNSResolver.local).to receive(:aaaa).and_return([])
    allow(DNSResolver.local).to receive(:a).and_return([])
  end

  describe "#start" do
    context "when no servers are provided to the class and there are no SMTP relays" do
      context "when there are MX records" do
        before do
          allow(DNSResolver.local).to receive(:mx).and_return([[5, "mx1.example.com"], [10, "mx2.example.com"]])
          allow(DNSResolver.local).to receive(:a).with("mx1.example.com").and_return(["1.2.3.4"])
          allow(DNSResolver.local).to receive(:a).with("mx2.example.com").and_return(["6.7.8.9"])
        end

        it "attempts to create an SMTP connection for each endpoint for each MX server for them" do
          endpoint = sender.start
          expect(endpoint).to be_a SMTPClient::Endpoint
          expect(endpoint).to have_attributes(
            ip_address: "1.2.3.4",
            server: have_attributes(hostname: "mx1.example.com", port: 25, ssl_mode: SMTPClient::SSLModes::AUTO)
          )
        end
      end

      context "when there are no MX records" do
        before do
          allow(DNSResolver.local).to receive(:mx).and_return([])
          allow(DNSResolver.local).to receive(:a).with("example.com").and_return(["1.2.3.4"])
        end

        it "attempts to create an SMTP connection for the domain itself" do
          endpoint = sender.start
          expect(endpoint).to be_a SMTPClient::Endpoint
          expect(endpoint).to have_attributes(
            ip_address: "1.2.3.4",
            server: have_attributes(hostname: "example.com", port: 25, ssl_mode: SMTPClient::SSLModes::AUTO)
          )
        end
      end

      context "when the MX lookup times out" do
        before do
          allow(DNSResolver.local).to receive(:mx).and_raise(Resolv::ResolvError.new("DNS resolv timeout: example.com"))
          allow(DNSResolver.local).to receive(:a).with("example.com").and_return(["1.2.3.4"])
        end

        it "raises an error" do
          expect { sender.start }.to raise_error Resolv::ResolvError
        end
      end
    end

    context "when there are no servers provided to the class but there are SMTP relays" do
      before do
        allow(SMTPSender).to receive(:smtp_relays).and_return([SMTPClient::Server.new("relay.example.com", port: 2525, ssl_mode: SMTPClient::SSLModes::TLS)])
        allow(DNSResolver.local).to receive(:a).with("relay.example.com").and_return(["1.2.3.4"])
      end

      it "attempts to use the relays" do
        endpoint = sender.start
        expect(endpoint).to be_a SMTPClient::Endpoint
        expect(endpoint).to have_attributes(
          ip_address: "1.2.3.4",
          server: have_attributes(hostname: "relay.example.com", port: 2525, ssl_mode: SMTPClient::SSLModes::TLS)
        )
      end
    end

    context "when there are servers provided to the class" do
      let(:server) { SMTPClient::Server.new("custom.example.com") }

      subject(:sender) { described_class.new("example.com", servers: [server]) }

      before do
        allow(DNSResolver.local).to receive(:a).with("custom.example.com").and_return(["1.2.3.4"])
      end

      it "uses the provided servers" do
        endpoint = sender.start
        expect(endpoint).to be_a SMTPClient::Endpoint
        expect(endpoint).to have_attributes(
          ip_address: "1.2.3.4",
          server: server
        )
      end
    end

    context "when a source IP is given without IPv6 and an endpoint is IPv6 enabled" do
      let(:source_ip_address) { create(:ip_address, ipv6: nil) }
      let(:server) { SMTPClient::Server.new("custom.example.com") }
      subject(:sender) { described_class.new("example.com", source_ip_address, servers: [server]) }

      before do
        allow(DNSResolver.local).to receive(:aaaa).with("custom.example.com").and_return(["2a00:67a0:a::1"])
        allow(DNSResolver.local).to receive(:a).with("custom.example.com").and_return(["1.2.3.4"])
      end

      it "returns the IPv4 version" do
        endpoint = sender.start
        expect(endpoint).to be_a SMTPClient::Endpoint
        expect(endpoint).to have_attributes(
          ip_address: "1.2.3.4",
          server: server
        )
      end
    end

    context "when there are no servers to connect to" do
      it "returns false" do
        expect(sender.start).to be false
      end
    end

    context "when the first server tried cannot be connected to" do
      let(:server1) { SMTPClient::Server.new("custom1.example.com") }
      let(:server2) { SMTPClient::Server.new("custom2.example.com") }

      let(:smtp_start_error) do
        proc do |endpoint|
          Errno::ECONNREFUSED if endpoint.ip_address == "1.2.3.4"
        end
      end

      before do
        allow(DNSResolver.local).to receive(:a).with("custom1.example.com").and_return(["1.2.3.4"])
        allow(DNSResolver.local).to receive(:a).with("custom2.example.com").and_return(["2.3.4.5"])
      end

      subject(:sender) { described_class.new("example.com", servers: [server1, server2]) }

      it "tries the second" do
        endpoint = sender.start
        expect(endpoint).to be_a SMTPClient::Endpoint
        expect(endpoint).to have_attributes(
          ip_address: "2.3.4.5",
          server: have_attributes(hostname: "custom2.example.com")
        )
      end

      it "includes both endpoints in the array of endpoints tried" do
        sender.start
        expect(sender.endpoints).to match([
                                            have_attributes(ip_address: "1.2.3.4"),
                                            have_attributes(ip_address: "2.3.4.5"),
                                          ])
      end
    end

    context "when the server returns an SSL error and SSL mode is Auto" do
      let(:server) { SMTPClient::Server.new("custom.example.com") }

      let(:smtp_start_error) do
        proc do |endpoint, allow_ssl|
          OpenSSL::SSL::SSLError if allow_ssl && endpoint.server.ssl_mode == "Auto"
        end
      end

      before do
        allow(DNSResolver.local).to receive(:aaaa).with("custom.example.com").and_return([])
        allow(DNSResolver.local).to receive(:a).with("custom.example.com").and_return(["1.2.3.4"])
      end

      subject(:sender) { described_class.new("example.com", servers: [server]) }

      it "attempts to reconnect without SSL" do
        endpoint = sender.start
        expect(endpoint).to be_a SMTPClient::Endpoint
        expect(endpoint).to have_attributes(ip_address: "1.2.3.4")
      end
    end
  end

  describe "#send_message" do
    let(:server) { create(:server) }
    let(:domain) { create(:domain, server: server) }
    let(:dns_result) { [] }
    let(:message) { MessageFactory.outgoing(server, domain: domain) }

    let(:smtp_client_server) { SMTPClient::Server.new("mx1.example.com") }
    subject(:sender) { described_class.new("example.com", servers: [smtp_client_server]) }

    before do
      allow(DNSResolver.local).to receive(:a).with("mx1.example.com").and_return(dns_result)
      sender.start
    end

    context "when there is no current endpoint to use" do
      it "returns a SoftFail" do
        result = sender.send_message(message)
        expect(result).to be_a SendResult
        expect(result).to have_attributes(
          type: "SoftFail",
          retry: true,
          output: "",
          details: /No SMTP servers were available for example.com. No hosts to try./,
          connect_error: true
        )
      end
    end

    context "when there is an endpoint" do
      let(:dns_result) { ["1.2.3.4"] }

      context "it sends the message to the endpoint" do
        context "if the message is a bounce" do
          let(:message) { MessageFactory.outgoing(server, domain: domain) { |m| m.bounce = true } }

          it "sends an empty MAIL FROM" do
            sender.send_message(message)
            expect(sender.endpoints.last).to have_received(:send_message).with(
              kind_of(String),
              "",
              ["john@example.com"]
            )
          end
        end

        context "if the domain has a valid custom return path" do
          let(:domain) { create(:domain, return_path_status: "OK") }

          it "sends the custom return path as MAIL FROM" do
            sender.send_message(message)
            expect(sender.endpoints.last).to have_received(:send_message).with(
              kind_of(String),
              "#{server.token}+#{message.token}@#{domain.return_path_domain}",
              ["john@example.com"]
            )
          end
        end

        context "if the domain has no valid custom return path" do
          it "sends the server default return path as MAIL FROM" do
            sender.send_message(message)
            expect(sender.endpoints.last).to have_received(:send_message).with(
              kind_of(String),
              "#{server.token}+#{message.token}@#{Postal::Config.dns.return_path_domain}",
              ["john@example.com"]
            )
          end
        end

        context "if the sender has specified an RCPT TO" do
          subject(:sender) { described_class.new("example.com", servers: [smtp_client_server], rcpt_to: "custom@example.com") }

          it "sends the specified RCPT TO" do
            sender.send_message(message)
            expect(sender.endpoints.last).to have_received(:send_message).with(
              kind_of(String),
              kind_of(String),
              ["custom@example.com"]
            )
          end
        end

        context "if the sender has not specified an RCPT TO" do
          it "uses the RCPT TO from the message" do
            sender.send_message(message)
            expect(sender.endpoints.last).to have_received(:send_message).with(
              kind_of(String),
              kind_of(String),
              ["john@example.com"]
            )
          end
        end

        context "if the configuration says to add the Resent-Sender header" do
          it "adds the resent-sender header" do
            sender.send_message(message)
            expect(sender.endpoints.last).to have_received(:send_message).with(
              "Resent-Sender: #{server.token}+#{message.token}@#{Postal::Config.dns.return_path_domain}\r\n#{message.raw_message}",
              kind_of(String),
              kind_of(Array)
            )
          end
        end

        context "if the configuration says to not add the Resent-From header" do
          before do
            allow(Postal::Config.postal).to receive(:use_resent_sender_header?).and_return(false)
          end

          it "does not add the resent-from header" do
            sender.send_message(message)
            expect(sender.endpoints.last).to have_received(:send_message).with(
              message.raw_message,
              kind_of(String),
              kind_of(Array)
            )
          end
        end
      end

      context "when the message is accepted" do
        it "returns a Sent result" do
          result = sender.send_message(message)
          expect(result).to be_a SendResult
          expect(result).to have_attributes(
            type: "Sent",
            details: "Message for john@example.com accepted by 1.2.3.4:25 (mx1.example.com)",
            output: "accepted"
          )
        end
      end

      context "when SMTP server is busy" do
        let(:smtp_send_message_error) { proc { Net::SMTPServerBusy.new("SMTP server was busy") } }

        it "returns a SoftFail" do
          result = sender.send_message(message)
          expect(result).to be_a SendResult
          expect(result).to have_attributes(
            type: "SoftFail",
            retry: true,
            details: /Temporary SMTP delivery error when sending/
          )
        end

        it "resets the endpoint SMTP sesssion" do
          sender.send_message(message)
          expect(sender.endpoints.last).to have_received(:reset_smtp_session)
        end
      end

      context "when the SMTP server returns an error if a retry time in seconds" do
        let(:smtp_send_message_error) { proc { Net::SMTPServerBusy.new("Try again in 30 seconds") } }

        it "returns a SoftFail with the retry time from the error" do
          result = sender.send_message(message)
          expect(result).to be_a SendResult
          expect(result).to have_attributes(
            type: "SoftFail",
            retry: 40
          )
        end
      end

      context "when the SMTP server returns an error if a retry time in minutes" do
        let(:smtp_send_message_error) { proc { Net::SMTPServerBusy.new("Try again in 5 minutes") } }

        it "returns a SoftFail with the retry time from the error" do
          result = sender.send_message(message)
          expect(result).to be_a SendResult
          expect(result).to have_attributes(
            type: "SoftFail",
            retry: 310
          )
        end
      end

      context "when there is an SMTP authentication error" do
        let(:smtp_send_message_error) { proc { Net::SMTPAuthenticationError.new("Denied") } }

        it "returns a SoftFail" do
          result = sender.send_message(message)
          expect(result).to be_a SendResult
          expect(result).to have_attributes(
            type: "SoftFail",
            details: /Temporary SMTP delivery error when sending/
          )
        end

        it "resets the endpoint SMTP sesssion" do
          sender.send_message(message)
          expect(sender.endpoints.last).to have_received(:reset_smtp_session)
        end
      end

      context "when there is a timeout" do
        let(:smtp_send_message_error) { proc { Net::ReadTimeout.new } }

        it "returns a SoftFail" do
          result = sender.send_message(message)
          expect(result).to be_a SendResult
          expect(result).to have_attributes(
            type: "SoftFail",
            details: /Temporary SMTP delivery error when sending/
          )
        end

        it "resets the endpoint SMTP sesssion" do
          sender.send_message(message)
          expect(sender.endpoints.last).to have_received(:reset_smtp_session)
        end
      end

      context "when there is an SMTP syntax error" do
        let(:smtp_send_message_error) { proc { Net::SMTPSyntaxError.new("Syntax error") } }

        it "returns a SoftFail" do
          result = sender.send_message(message)
          expect(result).to be_a SendResult
          expect(result).to have_attributes(
            type: "SoftFail",
            output: "Syntax error",
            details: /Temporary SMTP delivery error when sending/
          )
        end

        it "resets the endpoint SMTP sesssion" do
          sender.send_message(message)
          expect(sender.endpoints.last).to have_received(:reset_smtp_session)
        end
      end

      context "when there is an unknown SMTP error" do
        let(:smtp_send_message_error) { proc { Net::SMTPUnknownError.new("unknown error") } }

        it "returns a SoftFail" do
          result = sender.send_message(message)
          expect(result).to be_a SendResult
          expect(result).to have_attributes(
            type: "SoftFail",
            output: "unknown error",
            details: /Temporary SMTP delivery error when sending/
          )
        end

        it "resets the endpoint SMTP sesssion" do
          sender.send_message(message)
          expect(sender.endpoints.last).to have_received(:reset_smtp_session)
        end
      end

      context "when there is an fatal SMTP error" do
        let(:smtp_send_message_error) { proc { Net::SMTPFatalError.new("fatal error") } }

        it "returns a HardFail" do
          result = sender.send_message(message)
          expect(result).to be_a SendResult
          expect(result).to have_attributes(
            type: "HardFail",
            output: "fatal error",
            details: /Permanent SMTP delivery error when sending/
          )
        end

        it "resets the endpoint SMTP sesssion" do
          sender.send_message(message)
          expect(sender.endpoints.last).to have_received(:reset_smtp_session)
        end
      end

      context "when there is an unexpected error" do
        let(:smtp_send_message_error) { proc { ZeroDivisionError.new("divided by 0") } }

        it "returns a SoftFail" do
          result = sender.send_message(message)
          expect(result).to be_a SendResult
          expect(result).to have_attributes(
            type: "SoftFail",
            output: "divided by 0",
            details: /An error occurred while sending the message/
          )
        end

        it "resets the endpoint SMTP sesssion" do
          sender.send_message(message)
          expect(sender.endpoints.last).to have_received(:reset_smtp_session)
        end
      end
    end
  end

  describe "#finish" do
    let(:server) { SMTPClient::Server.new("custom.example.com") }

    subject(:sender) { described_class.new("example.com", servers: [server]) }

    let(:smtp_start_error) do
      proc do |endpoint|
        Errno::ECONNREFUSED if endpoint.ip_address == "1.2.3.4"
      end
    end

    before do
      allow(DNSResolver.local).to receive(:a).with("custom.example.com").and_return(["1.2.3.4", "2.3.4.5"])
      sender.start
    end

    it "calls finish_smtp_session on all endpoints" do
      sender.finish
      expect(sender.endpoints.size).to eq 2
      expect(sender.endpoints).to all have_received(:finish_smtp_session).at_least(:once)
    end
  end

  describe ".smtp_relays" do
    before do
      if described_class.instance_variable_defined?("@smtp_relays")
        described_class.remove_instance_variable("@smtp_relays")
      end
    end

    it "returns nil if smtp relays is nil" do
      allow(Postal::Config.postal).to receive(:smtp_relays).and_return(nil)
      expect(described_class.smtp_relays).to be nil
    end

    it "returns nil if there are no smtp relays" do
      allow(Postal::Config.postal).to receive(:smtp_relays).and_return([])
      expect(described_class.smtp_relays).to be nil
    end

    it "does not return relays where the host is nil" do
      allow(Postal::Config.postal).to receive(:smtp_relays).and_return([
                                                                         Hashie::Mash.new(host: nil, port: 25, ssl_mode: "Auto"),
                                                                         Hashie::Mash.new(host: "test.example.com", port: 25, ssl_mode: "Auto"),
                                                                       ])
      expect(described_class.smtp_relays).to match [kind_of(SMTPClient::Server)]
    end

    it "returns relays with options" do
      allow(Postal::Config.postal).to receive(:smtp_relays).and_return([
                                                                         Hashie::Mash.new(host: "test.example.com", port: 25, ssl_mode: "Auto"),
                                                                         Hashie::Mash.new(host: "test2.example.com", port: 2525, ssl_mode: "TLS"),
                                                                       ])
      expect(described_class.smtp_relays).to match [
        have_attributes(hostname: "test.example.com", port: 25, ssl_mode: "Auto"),
        have_attributes(hostname: "test2.example.com", port: 2525, ssl_mode: "TLS"),
      ]
    end
  end
end
