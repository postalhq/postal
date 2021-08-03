class ActionDeletionJob < Postal::Job

  def perform
    object = params["type"].constantize.deleted.find_by_id(params["id"])
    if object
      log "Deleting #{params['type']}##{params['id']}"
      object.destroy
      log "Deleted #{params['type']}##{params['id']}"
    else
      log "Couldn't find deleted object #{params['type']}##{params['id']}"
    end
  end

end
