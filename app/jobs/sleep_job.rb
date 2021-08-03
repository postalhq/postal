class SleepJob < Postal::Job

  def perform
    sleep 5
  end

end
