require "rails_helper"

describe Organization do
  context "model" do
    subject(:organization) { create(:organization) }

    it "should have a UUID" do
      expect(organization.uuid).to be_a String
      expect(organization.uuid.length).to eq 36
    end
  end
end
