require "rails_helper"

describe Postal::QueryString do
  it "should work with a single item" do
    qs = Postal::QueryString.new("to: test@example.com")
    expect(qs.to_hash["to"]).to eq "test@example.com"
  end

  it "should work with a multiple items" do
    qs = Postal::QueryString.new("to: test@example.com from: another@example.com")
    expect(qs.to_hash["to"]).to eq "test@example.com"
    expect(qs.to_hash["from"]).to eq "another@example.com"
  end

  it "should not require a space after the field name" do
    qs = Postal::QueryString.new("to:test@example.com from:another@example.com")
    expect(qs.to_hash["to"]).to eq "test@example.com"
    expect(qs.to_hash["from"]).to eq "another@example.com"
  end

  it "should return nil when it receives blank" do
    qs = Postal::QueryString.new("to:[blank]")
    expect(qs.to_hash["to"]).to eq nil
  end

  it "should handle dates with spaces" do
    qs = Postal::QueryString.new("date: 2017-02-12 15:20")
    expect(qs.to_hash["date"]).to eq("2017-02-12 15:20")
  end

  it "should return an array for multiple items" do
    qs = Postal::QueryString.new("to: test@example.com to: another@example.com")
    expect(qs.to_hash["to"]).to be_a(Array)
    expect(qs.to_hash["to"][0]).to eq "test@example.com"
    expect(qs.to_hash["to"][1]).to eq "another@example.com"
  end

  it "should work with a z in the string" do
    qs = Postal::QueryString.new("to: testaz@example.com")
    expect(qs.to_hash["to"]).to eq "testaz@example.com"
  end
end
