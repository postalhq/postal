# == Schema Information
#
# Table name: organization_users
#
#  id              :integer          not null, primary key
#  organization_id :integer
#  user_id         :integer
#  created_at      :datetime
#  admin           :boolean          default(FALSE)
#  all_servers     :boolean          default(TRUE)
#  user_type       :string(255)
#

class OrganizationUser < ApplicationRecord

  belongs_to :organization
  belongs_to :user, polymorphic: true, optional: true

end
