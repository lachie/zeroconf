Gem::Specification.new do |s|
  s.name = %q{zeroconf}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Lachie Cox"]
  s.date = %q{2008-06-29}
  s.description = %q{Crossplatform zeroconf (bonjour™) library.}
  s.email = %q{lachiec@gmail.com}
  s.extra_rdoc_files = ["README.rdoc"]
  s.files = ["README.rdoc", "Rakefile", "lib/dnssd.rb", "lib/net", "lib/net/dns", "lib/net/dns/mdns-sd.rb", "lib/net/dns/mdns.rb", "lib/net/dns/resolv-mdns.rb", "lib/net/dns/resolv-replace.rb", "lib/net/dns/resolv.rb", "lib/net/dns/resolvx.rb", "lib/net/dns.rb", "lib/zeroconf", "lib/zeroconf/common.rb", "lib/zeroconf/ext.rb", "lib/zeroconf/pure.rb", "lib/zeroconf/version.rb", "lib/zeroconf.rb", "originals/dnssd-0.6.0", "originals/dnssd-0.6.0/COPYING", "originals/dnssd-0.6.0/README", "originals/net-mdns-0.4", "originals/net-mdns-0.4/COPYING", "originals/net-mdns-0.4/README", "originals/net-mdns-0.4/TODO", "samples/exhttp.rb", "samples/exhttpv1.rb", "samples/exwebrick.rb", "samples/mdns-watch.rb", "samples/mdns.rb", "samples/test_dns.rb", "samples/v1demo.rb", "samples/v1mdns.rb", "test/stress", "test/stress/stress_register.rb", "test/test_browse.rb", "test/test_highlevel_api.rb", "test/test_register.rb", "test/test_resolve.rb", "test/test_resolve_ichat.rb", "test/test_textrecord.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/lachie/zeroconf}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.2.0}
  s.summary = %q{Crossplatform zeroconf (bonjour™) library.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if current_version >= 3 then
    else
    end
  else
  end
end
