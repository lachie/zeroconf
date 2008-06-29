=begin
  Copyright (C) 2005 Sam Roberts

  This library is free software; you can redistribute it and/or modify it
  under the same terms as the ruby language itself, see the file COPYING for
  details.
=end

require 'net/dns/mdns'

module Net
  module DNS

    # = DNS-SD over mDNS
    #
    # An implementation of DNS Service-Discovery (DNS-SD) using Net::DNS::MDNS.
    #
    # DNS-SD is described in draft-cheshire-dnsext-dns-sd.txt, see
    # http://www.dns-sd.org for more information. It is most often seen as part
    # of Apple's OS X, but is widely useful.
    #
    # These APIs accept and return a set of arguments which are documented once,
    # here, for convenience.
    #
    # - type: DNS-SD classifies services into types using a naming convention.
    #   That convention is <_service>.<_protocol>.  The underscores ("_") serve
    #   to differentiate from normal DNS names. Protocol is always one of
    #   "_tcp" or "_udp". The service is a short name, see the list at
    #   http://www.dns-sd.org/ServiceTypes.html. A common service is "http", the type
    #   of which would be "_http._tcp".
    #
    # - domain: Services operate in a domain, theoretically. In current practice,
    #   that domain is always "local".
    #
    # - name: Service lookup with #browse results in a name of a service of that
    #   type. That name is associated with a target (a host name), port,
    #   priority, and weight, as well as series of key to value mappings,
    #   specific to the service. In practice, priority and weight are widely
    #   ignored.
    #
    # - fullname: The concatention of the service name (optionally), type, and
    #   domain results in a single dot-seperated domain name - the "fullname".
    #   See Util.parse_name for more information about the format.
    #
    # - text_record: Service information in the form of key/value pairs.
    #   See Util.parse_strings for more information about the format.
    #
    # - flags: should return flags, similar to DNSSD, but for now we just return the
    #   TTL of the DNS message. A TTL of zero means a deregistration of the record.
    #
    # Services are advertised and resolved over specific network interfaces.
    # Currently, Net::DNS::MDNS supports only a single default interface, and
    # the interface will always be +nil+.
    module MDNSSD

      # A reply yielded by #browse, see MDNSSD for a description of the attributes.
      class BrowseReply
        attr_reader :interface, :fullname, :name, :type, :domain, :flags
        def initialize(an) # :nodoc:
          @interface = nil
          @fullname = an.name.to_s
          @domain, @type, @name = MDNSSD::Util.parse_name(an.data.name)
          @flags = an.ttl
        end
      end

      # Lookup a service by +type+ and +domain+.
      #
      # Yields a BrowseReply as services are found, in a background thread, not
      # the caller's thread!
      #
      # Returns a MDNS::BackgroundQuery, call MDNS::BackgroundQuery#stop when
      # you have found all the replies you are interested in.
      def self.browse(type, domain = '.local', *ignored) # :yield: BrowseReply
        dnsname = DNS::Name.create(type)
        dnsname << DNS::Name.create(domain)
        dnsname.absolute = true

        q = MDNS::BackgroundQuery.new(dnsname, IN::PTR) do |q, answers|
          answers.each do |an|
            yield BrowseReply.new( an )
          end
        end
        q
      end

      # A reply yielded by #resolve, see MDNSSD for a description of the attributes.
      class ResolveReply
        attr_reader :interface, :fullname, :name, :type, :domain, :target, :port, :priority, :weight, :text_record, :flags
        def initialize(ansrv, antxt) # :nodoc:
          @interface = nil
          @fullname = ansrv.name.to_s
          @domain, @type, @name = MDNSSD::Util.parse_name(ansrv.name)
          @target = ansrv.data.target.to_s
          @port = ansrv.data.port
          @priority = ansrv.data.priority
          @weight = ansrv.data.weight
          @text_record = MDNSSD::Util.parse_strings(antxt.data.strings)
          @flags = ansrv.ttl
        end
      end

      # Resolve a service instance by +name+, +type+ and +domain+.
      #
      # Yields a ResolveReply as service instances are found, in a background
      # thread, not the caller's thread!
      #
      # Returns a MDNS::BackgroundQuery, call MDNS::BackgroundQuery#stop when
      # you have found all the replies you are interested in.
      def self.resolve(name, type, domain = '.local', *ignored) # :yield: ResolveReply
        dnsname = DNS::Name.create(name)
        dnsname << DNS::Name.create(type)
        dnsname << DNS::Name.create(domain)
        dnsname.absolute = true

        rrs = {}

        q = MDNS::BackgroundQuery.new(dnsname, IN::ANY) do |q, answers|
          _rrs = {}
          answers.each do |an|
            if an.name == dnsname
              _rrs[an.type] = an
            end
          end
          # We queried for ANY, but don't yield unless we got a SRV or TXT.
          if( _rrs[IN::SRV] || _rrs[IN::TXT] )
            rrs.update _rrs

            ansrv, antxt = rrs[IN::SRV], rrs[IN::TXT]

#           puts "ansrv->#{ansrv}"
#           puts "antxt->#{antxt}"

            # Even though we got an SRV or TXT, we can't yield until we have both.
            if ansrv && antxt
              yield ResolveReply.new( ansrv, antxt )
            end
          end
        end
        q
      end

      # A reply yielded by #register, see MDNSSD for a description of the attributes.
      class RegisterReply
        attr_reader :interface, :fullname, :name, :type, :domain
        def initialize(name, type, domain)
          @interface = nil
          @fullname = (DNS::Name.create(name) << type << domain).to_s
          @name, @type, @domain = name, type, domain
        end
      end

      # Register a service instance on the local host.
      #
      # +txt+ is a Hash of String keys to String values.
      #
      # Because the service +name+ may already be in use on the network, a
      # different name may be registered than that requested. Because of this,
      # if a block is supplied, a RegisterReply will be yielded so that the
      # actual service name registered may be seen.
      #
      # Returns a MDNS::Service, call MDNS::Service#stop when you no longer
      # want to advertise the service.
      #
      # NOTE - The service +name+ should be unique on the network, MDNSSD
      # doesn't currently attempt to ensure this. This will be fixed in
      # an upcoming release.
      def self.register(name, type, domain, port, txt = {}, *ignored) # :yields: RegisterReply
        dnsname = DNS::Name.create(name)
        dnsname << DNS::Name.create(type)
        dnsname << DNS::Name.create(domain)
        dnsname.absolute = true

        s = MDNS::Service.new(name, type, port, txt) do |s|
          s.domain = domain
        end

        yield RegisterReply.new(name, type, domain) if block_given?

        s
      end

      # Utility routines not for general use.
      module Util
        # Decode a DNS-SD domain name. The format is:
        #   [<instance>.]<_service>.<_protocol>.<domain>
        #
        # Examples are:
        #   _http._tcp.local
        #   guest._http._tcp.local
        #   Ensemble Musique._daap._tcp.local
        #
        # The <_service>.<_protocol> combined is the <type>.
        #
        # Return either:
        #  [ <domain>, <type> ]
        # or
        #  [ <domain>, <type>, <instance>]
        #
        # Because of the order of the return values, it can be called like:
        #   domain, type = MDNSSD::Util.parse_name(fullname)
        # or
        #   domain, type, name = MDNSSD::Util.parse_name(fullname)
        # If there is no name component to fullname, name will be nil.
        def self.parse_name(dnsname)
          domain, t1, t0, name = dnsname.to_a.reverse.map {|n| n.to_s}
          [ domain, t0 + '.' + t1, name].compact
        end

        # Decode TXT record strings, an array of String.
        #
        # DNS-SD defines formatting conventions for them:
        # - Keys must be at least one char in range (0x20-0x7E), excluding '='
        #   (0x3D), and they must be matched case-insensitively.
        # - There may be no '=', in which case value is nil.
        # - There may be an '=' with no value, in which case value is empty string, "".
        # - Anything following the '=' is a value, it is not case sensitive, can be binary,
        #   and can include whitespace.
        # - Discard all keys but the first.
        # - Discard a string that aren't formatting accorded to these rules.
        def self.parse_strings(strings)
          h = {}

          strings.each do |kv|
            if kv.match( /^([\x20-\x3c\x3f-\x7e]+)(?:=(.*))?$/ )
              key = $1.downcase
              value = $2
              next if h.has_key? key
              h[key] = value
            end
          end

          h
        end
      end

    end
  end
end

