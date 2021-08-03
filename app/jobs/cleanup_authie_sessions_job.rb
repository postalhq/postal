require "authie/session"

class CleanupAuthieSessionsJob < Postal::Job

  def perform
    Authie::Session.cleanup
  end

end
