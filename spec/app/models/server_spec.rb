require "rails_helper"

describe Server do
  context "model" do
    subject(:server) { create(:server) }

    it "should have a UUID" do
      expect(server.uuid).to be_a String
      expect(server.uuid.length).to eq 36
    end
  end
end
