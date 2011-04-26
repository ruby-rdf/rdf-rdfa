#!/usr/bin/env ruby

require 'net/http'

url = URI.parse("http://www.bestbuy.com/shop/thermometers")

req = Net::HTTP::Get.new(url.path)
req.add_field("User-Agent", "Ruby RDF Distiller")
Net::HTTP.start(url.host, url.port) do |http|
  http.request(req) do |res|
    res.value # Raises HTTP error, unless response is successful
    puts "read returned:\n#{res.body}"
  end
end
