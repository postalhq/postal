require "highline"

module Postal
  module UserCreator

    def self.start(&block)
      cli = HighLine.new
      puts "\e[32mPostal User Creator\e[0m"
      puts "Enter the information required to create a new Postal user."
      puts "This tool is usually only used to create your initial admin user."
      puts
      user = User.new
      user.email_address = cli.ask("E-Mail Address".ljust(20, " ") + ": ")
      user.first_name = cli.ask("First Name".ljust(20, " ") + ": ")
      user.last_name = cli.ask("Last Name".ljust(20, " ") + ": ")
      user.password = cli.ask("Initial Password:".ljust(20, " ") + ": ") { |value| value.echo = "*" }

      block.call(user) if block_given?
      if user.save
        puts
        puts "User has been created with e-mail address \e[32m#{user.email_address}\e[0m"
        puts
      else
        puts
        puts "\e[31mFailed to create user\e[0m"
        for error in user.errors.full_messages
          puts " * #{error}"
        end
        puts
      end
    end

  end
end
