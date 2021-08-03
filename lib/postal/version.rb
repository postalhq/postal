module Postal

  VERSION_PATH = File.expand_path("../../VERSION", __dir__)
  VERSION = if File.file?(VERSION_PATH)
              File.read(VERSION_PATH).strip.delete_prefix("v")
            else
              "0.0.0-dev"
            end

  def self.version
    VERSION
  end

end
