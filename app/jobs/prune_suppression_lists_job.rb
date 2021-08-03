class PruneSuppressionListsJob < Postal::Job

  def perform
    Server.all.each do |s|
      log "Pruning suppression lists for server #{s.id}"
      s.message_db.suppression_list.prune
    end
  end

end
