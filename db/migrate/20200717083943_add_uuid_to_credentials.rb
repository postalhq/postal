class AddUUIDToCredentials < ActiveRecord::Migration[5.2]

  def change
    add_column :credentials, :uuid, :string
    Credential.find_each do |c|
      c.update_column(:uuid, SecureRandom.uuid)
    end
  end

end
