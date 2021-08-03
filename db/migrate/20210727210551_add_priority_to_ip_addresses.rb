class AddPriorityToIPAddresses < ActiveRecord::Migration[5.2]

  def change
    add_column :ip_addresses, :priority, :integer
    IPAddress.where(priority: nil).update_all(priority: 100)
  end

end
