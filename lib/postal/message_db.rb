module Postal
  module MessageDB

    extend ActiveSupport::Autoload
    eager_autoload do
      autoload :Click
      autoload :Database
      autoload :Delivery
      autoload :LiveStats
      autoload :Load
      autoload :Message
      autoload :Migration
      autoload :Provisioner
      autoload :Statistics
      autoload :SuppressionList
      autoload :Webhooks
    end

  end
end
