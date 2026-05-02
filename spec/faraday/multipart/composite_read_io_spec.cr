require "../../spec_helper"

private struct CompositePart
  include Faraday::Multipart::ReadablePart

  def initialize(@body : String)
  end

  def to_io : IO::Memory
    IO::Memory.new(@body)
  end

  def length : Int32
    @body.bytesize
  end
end

Spectator.describe Faraday::Multipart::CompositeReadIO do
  it "reads an empty composite" do
    io = Faraday::Multipart::CompositeReadIO.new

    expect(io.length).to eq(0)
    expect(io.read).to eq("")
    expect(io.read(1)).to be_nil
  end

  it "reads multiple parts in order" do
    io = Faraday::Multipart::CompositeReadIO.new(CompositePart.new("abcd"), CompositePart.new("1234"))

    expect(io.length).to eq(8)
    expect(io.read).to eq("abcd1234")
  end

  it "reads in chunks and stops at the end" do
    io = Faraday::Multipart::CompositeReadIO.new(CompositePart.new("abcd"), CompositePart.new("1234"))

    expect(io.read(3)).to eq("abc")
    expect(io.read(3)).to eq("d12")
    expect(io.read(3)).to eq("34")
    expect(io.read(3)).to be_nil
  end

  it "rewinds back to the start" do
    io = Faraday::Multipart::CompositeReadIO.new(CompositePart.new("abcd"), CompositePart.new("1234"))

    expect(io.read(5)).to eq("abcd1")
    io.rewind
    expect(io.read(4)).to eq("abcd")
  end

  it "still returns the chunk when given an output buffer" do
    io = Faraday::Multipart::CompositeReadIO.new(CompositePart.new("ab"), CompositePart.new("cd"))

    expect(io.read(3, "noise")).to eq("abc")
  end
end
