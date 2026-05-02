require "../../spec_helper"

module MiddlewareSpecSupport
  extend self

  def build_conn(flat_encode : Bool = false, content_type : String? = nil) : Faraday::Connection
    adapter = Faraday::Adapter::Test.new
    adapter.stub(:post, "/echo") do |env|
      posted_as = env.request_headers["Content-Type"]? || ""
      {200, HTTP::Headers{"Content-Type" => posted_as}, env.request_body.to_s}
    end

    Faraday.new do |conn|
      if content_type
        conn.request :multipart, flat_encode: flat_encode, content_type: content_type
      elsif flat_encode
        conn.request :multipart, flat_encode: true
      else
        conn.request :multipart
      end
      conn.request :url_encoded
      conn.adapter(adapter)
    end
  end
end

Spectator.describe Faraday::Multipart::Middleware do
  it "generates a unique boundary for each request" do
    conn = MiddlewareSpecSupport.build_conn
    payload = {
      "a"    => 1,
      "file" => Faraday::Multipart::FilePart.new(__FILE__, "text/x-ruby"),
    } of String => Faraday::Multipart::Value

    response1 = conn.post("/echo", payload)
    response2 = conn.post("/echo", payload)

    boundary1 = Faraday::Multipart::HelperMethods.parse_multipart_boundary(response1.headers["Content-Type"])
    boundary2 = Faraday::Multipart::HelperMethods.parse_multipart_boundary(response2.headers["Content-Type"])
    expect(boundary1).not_to eq(boundary2)
  end

  it "serializes nested file parts" do
    conn = MiddlewareSpecSupport.build_conn
    nested = {
      "c" => Faraday::Multipart::FilePart.new(
        __FILE__,
        "text/x-ruby",
        nil,
        {"Content-Disposition" => "form-data; foo=1"}
      ),
      "d" => 2,
    } of String => Faraday::Multipart::Value
    payload = {
      "a" => 1,
      "b" => nested,
    } of String => Faraday::Multipart::Value

    response = conn.post("/echo", payload)
    boundary = Faraday::Multipart::HelperMethods.parse_multipart_boundary(response.headers["Content-Type"])
    result = Faraday::Multipart::HelperMethods.parse_multipart(boundary, response.body.to_s)

    expect(result.errors).to be_empty
    part_a = result.part("a").not_nil!
    expect(part_a.filename).to be_nil
    expect(part_a.body).to eq("1")

    part_bc = result.part("b[c]").not_nil!
    expect(part_bc.filename).to eq("middleware_spec.cr")
    expect(part_bc.headers["Content-Disposition"]).to eq(%(form-data; foo=1; name="b[c]"; filename="middleware_spec.cr"))
    expect(part_bc.headers["Content-Type"]).to eq("text/x-ruby")
    expect(part_bc.headers["Content-Transfer-Encoding"]).to eq("binary")
    expect(part_bc.body).to eq(File.read(__FILE__))

    part_bd = result.part("b[d]").not_nil!
    expect(part_bd.body).to eq("2")
  end

  it "serializes param parts and file parts together" do
    conn = MiddlewareSpecSupport.build_conn
    io = IO::Memory.new("io-content")
    payload = {
      "json" => Faraday::Multipart::ParamPart.new({b: 1, c: 2}.to_json, "application/json"),
      "io"   => Faraday::Multipart::FilePart.new(io, "application/pdf"),
    } of String => Faraday::Multipart::Value

    response = conn.post("/echo", payload)
    boundary = Faraday::Multipart::HelperMethods.parse_multipart_boundary(response.headers["Content-Type"])
    result = Faraday::Multipart::HelperMethods.parse_multipart(boundary, response.body.to_s)

    part_json = result.part("json").not_nil!
    expect(part_json.mime).to eq("application/json")
    expect(part_json.body).to eq(%({"b":1,"c":2}))

    part_io = result.part("io").not_nil!
    expect(part_io.mime).to eq("application/pdf")
    expect(part_io.filename).to eq("local.path")
    expect(part_io.body).to eq("io-content")
  end

  it "serializes arrays with bracketed keys by default" do
    conn = MiddlewareSpecSupport.build_conn
    item = {
      "c" => Faraday::Multipart::FilePart.new(__FILE__, "text/x-ruby"),
      "d" => 2,
    } of String => Faraday::Multipart::Value
    items = [item] of Faraday::Multipart::Value
    payload = {
      "a" => 1,
      "b" => items,
    } of String => Faraday::Multipart::Value

    response = conn.post("/echo", payload)
    boundary = Faraday::Multipart::HelperMethods.parse_multipart_boundary(response.headers["Content-Type"])
    result = Faraday::Multipart::HelperMethods.parse_multipart(boundary, response.body.to_s)

    expect(result.part("b[][c]").not_nil!.filename).to eq("middleware_spec.cr")
    expect(result.part("b[][d]").not_nil!.body).to eq("2")
  end

  it "flattens array keys when asked" do
    conn = MiddlewareSpecSupport.build_conn(flat_encode: true)
    io = IO::Memory.new("io-content")
    items = [
      Faraday::Multipart::FilePart.new(io, "application/pdf"),
      Faraday::Multipart::FilePart.new(io, "application/pdf"),
    ] of Faraday::Multipart::Value
    payload = {
      "a" => 1,
      "b" => items,
    } of String => Faraday::Multipart::Value

    response = conn.post("/echo", payload)
    expect(response.body.to_s).to contain(%(name="b"))
    expect(response.body.to_s).not_to contain(%(name="b[]"))
  end

  it "uses a multipart content type override and falls back for non-multipart types" do
    payload = {
      "xml" => Faraday::Multipart::ParamPart.new("<xml><value /></xml>", "text/xml"),
      "io"  => Faraday::Multipart::FilePart.new(IO::Memory.new("io-content"), "application/octet-stream"),
    } of String => Faraday::Multipart::Value

    mixed = MiddlewareSpecSupport.build_conn(content_type: "multipart/mixed").post("/echo", payload)
    defaulted = MiddlewareSpecSupport.build_conn(content_type: "application/json").post("/echo", payload)

    expect(mixed.headers["Content-Type"]).to start_with("multipart/mixed")
    expect(defaulted.headers["Content-Type"]).to start_with("multipart/form-data")
  end
end
