#!/usr/local/bin/ruby18 -w
# Author: Sam Roberts <sroberts@uniserve.com>
# Licence: this file is placed in the public domain
#
# Advertise a webrick server over mDNS.

require 'webrick'
require 'net/dns/mdns-sd'

DNSSD = Net::DNS::MDNSSD

class HelloServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, resp)   
    resp.body = "hello, world\n"
    resp['content-type'] = 'text/plain'
    raise WEBrick::HTTPStatus::OK
  end
end

# This may seem convoluted... but if there are multiple address families
# available, like AF_INET6 and AF_INET, this should create multiple TCPServer
# sockets for them.
families = Socket.getaddrinfo(nil, 1, Socket::AF_UNSPEC, Socket::SOCK_STREAM, 0, Socket::AI_PASSIVE)

listeners = []
port = 0

families.each do |af, one, dns, addr|
  p port, addr
  listeners << TCPServer.new(addr, port)
  port = listeners.first.addr[1] unless port != 0
end

listeners.each do |s|
  puts "listen on #{s.addr.inspect}"
end

# This will dynamically allocate multiple TCPServers, each on a different port.
server = WEBrick::HTTPServer.new( :Port => 0 )

# So we replace them with our TCPServer sockets which are all on the same
# (dynamically assigned) port.
server.listeners.each do |s| s.close end
server.listeners.replace listeners
server.config[:Port] = port

server.mount( '/hello/', HelloServlet )

handle = DNSSD.register("hello", '_http._tcp', 'local', port, 'path' => '/hello/')

['INT', 'TERM'].each { |signal| 
  trap(signal) { server.shutdown; handle.stop; }
}

server.start

