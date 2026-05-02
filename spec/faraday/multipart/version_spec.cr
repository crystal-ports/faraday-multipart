require "../../spec_helper"

Spectator.describe Faraday::Multipart::VERSION do
  it "looks like a release version" do
    expect(Faraday::Multipart::VERSION).to match(/^\d+\.\d+\.\d+(\.\w+(\.\d+)?)?$/)
  end
end
