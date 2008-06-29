=begin
  Copyright (C) 2005 Sam Roberts

  This library is free software; you can redistribute it and/or modify it
  under the same terms as the ruby language itself, see the file COPYING for
  details.
=end

require 'net/dns/resolvx'

BasicSocket.do_not_reverse_lookup = true

module Net
  # DNS exposes some of Resolv::DNS from resolv.rb to make them easier to use
  # outside of the context of the Resolv class and it's DNS resolver - such as
  # in MDNS. In particular, Net::DNS can be included so that full names to DNS
  # classes in Resolv::DNS can be imported into your namespace.
  module DNS

    Message      = Resolv::DNS::Message
    Name         = Resolv::DNS::Name
    DecodeError  = Resolv::DNS::DecodeError

    module IN
      A      = Resolv::DNS::Resource::IN::A
      AAAA   = Resolv::DNS::Resource::IN::AAAA
      ANY    = Resolv::DNS::Resource::IN::ANY
      CNAME  = Resolv::DNS::Resource::IN::CNAME
      HINFO  = Resolv::DNS::Resource::IN::HINFO
      MINFO  = Resolv::DNS::Resource::IN::MINFO
      MX     = Resolv::DNS::Resource::IN::MX
      NS     = Resolv::DNS::Resource::IN::NS
      PTR    = Resolv::DNS::Resource::IN::PTR
      SOA    = Resolv::DNS::Resource::IN::SOA
      SRV    = Resolv::DNS::Resource::IN::SRV
      TXT    = Resolv::DNS::Resource::IN::TXT
      WKS    = Resolv::DNS::Resource::IN::WKS
    end

    # Returns the resource record name of +rr+ as a short string ("IN::A",
    # ...).
    def self.rrname(rr)
      rr = rr.class unless rr.class == Class
      rr = rr.to_s.sub(/.*Resource::/, '')
      rr = rr.to_s.sub(/.*DNS::/, '')
    end
  end
end

