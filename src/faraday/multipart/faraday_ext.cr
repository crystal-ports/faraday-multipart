module Faraday
  class Env
    property multipart_body : Faraday::Multipart::Value?
  end

  class RackBuilder
    def request(key : Symbol)
      case key
      when :multipart
        use_handler(Faraday::Multipart::Middleware, "Faraday::Multipart::Middleware",
          ->(app : Handler) { Faraday::Multipart::Middleware.new(app).as(Handler) })
      when :url_encoded
        use_class(Request::UrlEncoded)
      else
        raise Faraday::Error.new("Unknown request middleware: #{key.inspect}")
      end
    end

    def request(key : Symbol, *, flat_encode : Bool = false, content_type : String? = nil)
      if key == :multipart
        options = Faraday::Multipart::Options.new(flat_encode, content_type)
        use_handler(Faraday::Multipart::Middleware, "Faraday::Multipart::Middleware",
          ->(app : Handler) { Faraday::Multipart::Middleware.new(app, options).as(Handler) })
      else
        request(key)
      end
    end
  end

  class Connection
    def request(key : Symbol)
      @builder.request(key)
    end

    def request(key : Symbol, *, flat_encode : Bool = false, content_type : String? = nil)
      @builder.request(key, flat_encode: flat_encode, content_type: content_type)
    end

    def post(body : Hash(K, V), headers = nil) : Response forall K, V
      run_multipart_request(:post, nil, body, headers)
    end

    def post(url : String, body : Hash(K, V), headers = nil) : Response forall K, V
      run_multipart_request(:post, url, body, headers)
    end

    def put(body : Hash(K, V), headers = nil) : Response forall K, V
      run_multipart_request(:put, nil, body, headers)
    end

    def put(url : String, body : Hash(K, V), headers = nil) : Response forall K, V
      run_multipart_request(:put, url, body, headers)
    end

    def patch(body : Hash(K, V), headers = nil) : Response forall K, V
      run_multipart_request(:patch, nil, body, headers)
    end

    def patch(url : String, body : Hash(K, V), headers = nil) : Response forall K, V
      run_multipart_request(:patch, url, body, headers)
    end

    private def run_multipart_request(method : Symbol, url : String?, body : Hash(K, V), headers = nil) : Response forall K, V
      unless @builder.handlers.any? { |handler| handler.name == "Faraday::Multipart::Middleware" }
        raise Faraday::Error.new("Hash bodies require the :multipart middleware")
      end

      request = build_request(method) do |req|
        req.url(url) if url
        if h = headers
          h.each { |key, value| req.headers[key.to_s] = value.to_s }
        end
      end

      env = @builder.build_env(self, request)
      env.multipart_body = Faraday::Multipart.normalize(body)
      @builder.app.call(env)
    end
  end
end
