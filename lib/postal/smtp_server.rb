module Postal
  module SMTPServer

    extend ActiveSupport::Autoload
    eager_autoload do
      autoload :Client
      autoload :Server
    end

  end
end
