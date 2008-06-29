=begin
  Copyright (C) 2005 Sam Roberts

  This library is free software; you can redistribute it and/or modify it
  under the same terms as the ruby language itself, see the file COPYING for
  details.
=end

require 'net/dns/resolvx'
require 'net/dns/mdns'

class Resolv
  # == Address Lookups
  # Requiring 'net/dns/mdns-resolv' causes a Resolv::MDNS resolver to be added
  # to list of default resolvers queried when using Resolv#getaddress, and the
  # other Resolv module methods.
  #
  # It can be used by doing:
  #   require 'net/dns/resolv-mdns'
  #   Resolv.getaddress('localhost')       # resolved using Resolv::Hosts("/etc/hosts")
  #   Resolv.getaddress('www.example.com') # resolved using Resolv::DNS
  #   Resolv.getaddress('example.local')   # resolved using Resolv::MDNS
  #
  # Using this approach means that both global DNS names and local names can be
  # resolved.  When doing this, you may also consider doing:
  #
  #   require 'net/dns/resolv-mdns'
  #   require 'net/dns/resolv-replace'
  #
  # This has the effect of replacing the default ruby implementation of address
  # lookup using the C library in IPSocket, TCPSocket, UDPSocket, and
  # SOCKSocket with Resolv.getaddress. Since 'net/dns/resolv-mdns' has been
  # required Resolv.getaddress and the standard libraries TCP/IP classes will
  # use mDNS for name lookups in the .local mDNS domain, without even knowing
  # it themselves.
  #
  # NOTE: the version of resolv.rb and resolv-replace.rb in net-mdns are based
  # on the head of ruby 1.8.x cvs + bug fixes required by net-mdns and not
  # present in the cvs. They must be used in place of the standard library's
  # resolv implementation!
  #
  # == Service Discovery (DNS-SD)
  #
  # Service discovery consists of 2 stages:
  # - enumerating the names of the instances of the service
  # - resolving the instance names
  #
  # The Net::DNS::MDNSSD API is better documented and easier to use for DNS-SD.
  # Still, here's some information on using the Resolv APIs for DNS-SD, and
  # examples of doing so are:
  # - link:exhttpv1.txt
  # - link:v1mdns.txt
  # - link:v1demo.txt.
  #
  # = Service Enumeration
  #
  # To do this query the pointer records (Resolv::DNS::Resource::IN::PTR) for
  # names of the form _svc._prot.local. The values of svc and prot for common
  # services can be found at http://www.dns-sd.org/ServiceTypes.html.
  # The first label of the name returned is suitable for display to people, and
  # should be unique in the network.
  #
  # = Service Resolution
  #
  # In order to resolve a service name query the service record
  # (Resolv::DNS::Resource::IN::SRV) for the name. The service record contains
  # a host and port to connect to. The host name will have to be resolved to an
  # address. This can be done explicitly using mDNS or, if resolv-replace has
  # been required, it will be done by the standard library.  In addition, some
  # services put "extra" information about the service in a text
  # (Resolv::DNS::Resource::IN::TXT) record associated with the service name.
  # The format of the text record is service-specific.
  class MDNS

    # How many seconds to wait before assuming all responses have been seen.
    DefaultTimeout = 2

    # See Resolv::DNS#new.
    def initialize(config_info=nil)
      @mutex = Mutex.new
      @config = DNS::Config.new(config_info)
      @initialized = nil
    end

    def lazy_initialize # :nodoc:
      @mutex.synchronize do
        unless @initialized
          @config.lazy_initialize
          @initialized = true
        end
      end
    end

    # See Resolv::DNS#getaddress.
    def getaddress(name)
      each_address(name) {|address| return address}
      raise ResolvError.new("mDNS result has no information for #{name}")
    end

    # See Resolv::DNS#getaddresss.
    def getaddresses(name)
      ret = []
      each_address(name) {|address| ret << address}
      return ret
    end

    # See Resolv::DNS#each_address.
    def each_address(name)
      each_resource(name, DNS::Resource::IN::A) {|resource| yield resource.address}
    end

    # See Resolv::DNS#getname.
    def getname(address)
      each_name(address) {|name| return name}
      raise ResolvError.new("mDNS result has no information for #{address}")
    end

    # See Resolv::DNS#getnames.
    def getnames(address)
      ret = []
      each_name(address) {|name| ret << name}
      return ret
    end

    # See Resolv::DNS#each_name.
    def each_name(address)
      case address
      when DNS::Name
        ptr = address
      when IPv4::Regex
        ptr = IPv4.create(address).to_name
      when IPv6::Regex
        ptr = IPv6.create(address).to_name
      else
        raise ResolvError.new("cannot interpret as address: #{address}")
      end
      each_resource(ptr, DNS::Resource::IN::PTR) {|resource| yield resource.name}
    end

    # See Resolv::DNS#getresource.
    def getresource(name, typeclass)
      each_resource(name, typeclass) {|resource| return resource}
      raise ResolvError.new("mDNS result has no information for #{name}")
    end

    # See Resolv::DNS#getresources.
    def getresources(name, typeclass)
      ret = []
      each_resource(name, typeclass) {|resource| ret << resource}
      return ret
    end

    def generate_candidates(name) # :nodoc:
      # Names ending in .local MUST be resolved using mDNS. Other names may be, but
      # SHOULD NOT be, so a local machine can't spoof a non-local address.
      #
      # Reverse lookups in the domain '.254.169.in-addr.arpa' should also be resolved
      # using mDNS.
      #
      # TODO - those are the IPs auto-allocated with ZeroConf. In my (common)
      # situation, I have a net of OS X machines behind and ADSL firewall box,
      # and all IPs were allocated in 192.168.123.*. I can do mDNS queries to
      # get these addrs, but I can't do an mDNS query to reverse lookup the
      # addrs. There are security reasons to not allow all addrs to be reversed
      # on the local network, but maybe it wouldn't be so bad if MDNS was after
      # DNS, so it only did it for addrs that were unmatched by DNS?
      #
      # Or perhaps IP addrs in the netmask of the ifx should be considered local,
      # and mDNS allowed on them?
      #
      # If the search domains includes .local, we can add .local to it only if
      # it has no dots and wasn't absolute.
      lazy_initialize
      dotlocal = DNS::Name.create('local')
      search_dotlocal = @config.search.map.include?( dotlocal.to_a )
      name = DNS::Name.create(name)
      if name.absolute?
        name = name
      elsif name.length == 1 && search_dotlocal
        name = name + dotlocal
      elsif name.length > 1
        name = name
      else
        name = nil
      end
      if name.subdomain_of?('local') || name.subdomain_of?('254.169.in-addr.arpa')
        name.absolute = true
        name
      else
        nil
      end
    end

    # See Resolv::DNS#eachresource.
    def each_resource(name, typeclass)
      name = generate_candidates(name)

      query = Net::DNS::MDNS::Query.new(name, typeclass)

      begin
        # We want all the answers we can get, within the timeout period.
        begin
          timeout(DefaultTimeout) do
            query.each do |answers|
              answers.each do |an|
                yield an.data
              end
            end
          end
        rescue TimeoutError
        end
      ensure
        query.stop
      end
    end

    Default = Resolv::MDNS.new

    # Return the default MDNS Resolver. This is what is used when
    # Resolv.getaddress and friends are called. Use it unless you need to
    # specify config_info to Resolv::MDNS.new.
    def self.default
      Default
    end

  end

  DefaultResolver.resolvers.push( Resolv::MDNS.default )
end

