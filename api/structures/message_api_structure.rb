structure :message do
  basic :id
  basic :token

  expansion(:status) {
    {
      status: o.status,
      last_delivery_attempt: o.last_delivery_attempt ? o.last_delivery_attempt.to_f : nil,
      held: o.held == 1 ? true : false,
      hold_expiry: o.hold_expiry ? o.hold_expiry.to_f : nil
    }
  }

  expansion(:details) {
    {
      rcpt_to: o.rcpt_to,
      mail_from: o.mail_from,
      subject: o.subject,
      message_id: o.message_id,
      timestamp: o.timestamp.to_f,
      direction: o.scope,
      size: o.size,
      bounce: o.bounce,
      bounce_for_id: o.bounce_for_id,
      tag: o.tag,
      received_with_ssl: o.received_with_ssl
    }
  }

  expansion(:inspection) {
    {
      inspected: o.inspected == 1 ? true : false,
      spam: o.spam == 1 ? true : false,
      spam_score: o.spam_score.to_f,
      threat: o.threat == 1 ? true : false,
      threat_details: o.threat_details
    }
  }

  expansion(:plain_body) { o.plain_body }

  expansion(:html_body) { o.html_body }

  expansion(:attachments) {
    o.attachments.map do |attachment|
      {
        filename: attachment.filename.to_s,
        content_type: attachment.mime_type,
        data: Base64.encode64(attachment.body.to_s),
        size: attachment.body.to_s.bytesize,
        hash: Digest::SHA1.hexdigest(attachment.body.to_s)
      }
    end
  }

  expansion(:headers) { o.headers }

  expansion(:raw_message) { Base64.encode64(o.raw_message) }

  expansion(:activity_entries) {
    {
      loads: o.loads,
      clicks: o.clicks
    }
  }
end
