#!/usr/local/bin/ruby18

require 'socket'
require 'ipaddr'
require 'net/dns'

$stderr.sync = true
$stdout.sync = true

Addr = "224.0.0.251"
Port = 5353

include Net::DNS

@hostname = Name.create(Socket.gethostname)
@hostname.absolute = true
@hostaddr = Socket.getaddrinfo(@hostname.to_s, 0, Socket::AF_INET, Socket::SOCK_STREAM)[0][3]
@hostrr   = [ @hostname, 240, IN::A.new(@hostaddr) ]
@hostaddr = IPAddr.new(@hostaddr).hton

@sock = UDPSocket.new

# TODO - do we need this?
@sock.fcntl(Fcntl::F_SETFD, 1)

# Allow 5353 to be shared.
so_reuseport = 0x0200 # The definition on OS X, where it is required.
if Socket.constants.include? 'SO_REUSEPORT'
  so_reuseport = Socket::SO_REUSEPORT
end
begin
  @sock.setsockopt(Socket::SOL_SOCKET, so_reuseport, 1)
rescue
  warn( "set SO_REUSEPORT raised #{$!}, try SO_REUSEADDR" )
  so_reuseport = Socket::SO_REUSEADDR
  @sock.setsockopt(Socket::SOL_SOCKET, so_reuseport, 1)
end

# Request dest addr and ifx ids... no.

# Join the multicast group.
#  option is a struct ip_mreq { struct in_addr, struct in_addr }
ip_mreq =  IPAddr.new(Addr).hton + @hostaddr
@sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, ip_mreq)
@sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_IF, @hostaddr)

# Set IP TTL for outgoing packets.
@sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_TTL, 255)
@sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_TTL, 255)

# Apple source makes it appear that optval may need to be a "char" on
# some systems:
#  @sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_TTL, 255 as int)
#     - or -
#  @sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_TTL, 255 as byte)

# Bind to our port.
@sock.bind(Socket::INADDR_ANY, Port)

class Resolv
  class DNS
    class Resource
      module IN
        class SRV
          def inspect
            "#{target}:#{port} weight=#{weight} priority=#{priority}"
          end
        end
        class TXT
          def inspect
            strings.inspect
          end
        end
        class PTR
          def inspect
            name.to_s
          end
        end
        class A
          def inspect
            address.to_s
          end
        end
        class HINFO
          def inspect
            "os=#{os.inspect}\ncpu=#{cpu.inspect}"
          end
        end
      end
    end
  end
end

loop do

  reply, from = @sock.recvfrom(9000)

  puts "++ from #{from.inspect}"

  if false
    puts reply.inspect
    puts "--"
  end

  msg = Resolv::DNS::Message.decode(reply)

  qr = msg.qr==0 ? 'Q' : 'R'
  qrstr = msg.qr==0 ? 'Query' : 'Resp'

  opcode = { 0=>'QUERY', 1=>'IQUERY', 2=>'STATUS'}[msg.opcode]

  puts "#{qrstr}: id #{msg.id} qr #{qr} opcode #{opcode} aa #{msg.aa} tc #{msg.tc} rd #{msg.rd} ra #{msg.ra} rcode #{msg.rcode}"

  msg.question.each do |name, type, unicast|
    puts "qu #{Net::DNS.rrname type} #{name.to_s.inspect} unicast=#{unicast}"
  end
  msg.answer.each do |name, ttl, data, cacheflush|
    puts "an #{Net::DNS.rrname data} #{name.to_s.inspect} ttl=#{ttl} cacheflush=#{cacheflush}"
    puts "   #{data.inspect}"
  end
  msg.authority.each do |name, ttl, data, cacheflush|
    puts "au #{Net::DNS.rrname data} #{name.to_s.inspect} ttl=#{ttl} cacheflush=#{cacheflush.inspect}"
    puts "   #{data.inspect}"
  end
  msg.additional.each do |name, ttl, data, cacheflush|
    puts "ad #{Net::DNS.rrname data} #{name.to_s.inspect} ttl=#{ttl} cacheflush=#{cacheflush.inspect}"
    puts "   #{data.inspect}"
  end

  puts
end

