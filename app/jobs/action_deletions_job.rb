class ActionDeletionsJob < Postal::Job

  def perform
    Organization.deleted.each do |org|
      log "Permanently removing organization #{org.id} (#{org.permalink})"
      org.destroy
    end

    Server.deleted.each do |server|
      log "Permanently removing server #{server.id} (#{server.full_permalink})"
      server.destroy
    end
  end

end
