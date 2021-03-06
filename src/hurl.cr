require "json"
require "raze"
require "./hurl/exception"
require "./hurl/link"
require "./hurl/middleware"
require "./hurl/cache"

module Hurl
  {% if flag?(:memory_cache) %}
    @@cache = Memory.new
  {% else %}
    @@cache = Redis.new
  {% end %}

  # Resolves a link code and executes a redirect.
  # If the requester will `Accept` `application/json`,
  # the `Link` object as JSON is returned instead and no
  # redirect is performed.
  get "/:code", Logger.new do |ctx|
    code = ctx.params["code"].as(String)

    if link = @@cache.resolve(code)
      if ctx.request.headers["Accept"] == "application/json"
        link.to_json
      else
        link.use
        ctx.redirect link.target.to_s
      end
    else
      ctx.halt "Not Found", 404
    end
  end

  # Creates a new Link.
  # This route requires a User-Agent that passes the `RequireUserAgent` middleware.
  # The JSON at minimum must contain a string `target` key, which must
  # have an HTTPS scheme and respond to a HEAD request with a 200 response.
  # Returns the created `Link` object.
  post "/", Logger.new, RequireUserAgent.new, JSONContentType.new do |ctx|
    begin
      link = Link.new(ctx.request.body.as(IO))
      @@cache.store(link)
      link.to_json
    rescue ex : JSON::ParseException
      ctx.halt_plain "Invalid JSON Body (#{ex.class}): #{ex.message}", 400
    rescue ex : HurlException
      ctx.halt_plain "#{ex.class} (#{ex.message})", 400
    end
  end
end

Raze.run
