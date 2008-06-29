#!/usr/bin/ruby -w

$:.unshift File.dirname($0)

require 'net/dns/resolvx.rb'
require 'test/unit'

require 'pp'

Name = Resolv::DNS::Name

class TestDns < Test::Unit::TestCase

  def test_name_what_I_think_are_odd_behaviours
    # Why can't test against strings?
    assert_equal(false, Name.create("example.CoM") ==   "example.com")
    assert_equal(false, Name.create("example.CoM").eql?("example.com"))

    # Why does making it absolute mean they aren't equal?
    assert_equal(false, Name.create("example.CoM").eql?(Name.create("example.com.")))
    assert_equal(false, Name.create("example.CoM") ==   Name.create("example.com."))
  end

  def test_name_CoMparisons

    assert_equal(true,  Name.create("example.CoM").eql?(Name.create("example.com")))
    assert_equal(true,  Name.create("example.CoM") ==   Name.create("example.com"))

    assert_equal(true,  Name.create("example.CoM").equal?("example.com."))
    assert_equal(true,  Name.create("example.CoM").equal?("example.com"))

    assert_equal(true,  Name.create("www.example.CoM") <   "example.com")
    assert_equal(true,  Name.create("www.example.CoM") <=  "example.com")
    assert_equal(-1,    Name.create("www.example.CoM") <=> "example.com")
    assert_equal(false, Name.create("www.example.CoM") >=  "example.com")
    assert_equal(false, Name.create("www.example.CoM") >   "example.com")

    assert_equal(false, Name.create("example.CoM") <   "example.com")
    assert_equal(true,  Name.create("example.CoM") <=  "example.com")
    assert_equal(0,     Name.create("example.CoM") <=> "example.com")
    assert_equal(true,  Name.create("example.CoM") >=  "example.com")
    assert_equal(false, Name.create("example.CoM") >   "example.com")

    assert_equal(false, Name.create("CoM") <   "example.com")
    assert_equal(false, Name.create("CoM") <=  "example.com")
    assert_equal(+1,    Name.create("CoM") <=> "example.com")
    assert_equal(true,  Name.create("CoM") >=  "example.com")
    assert_equal(true,  Name.create("CoM") >   "example.com")

    assert_equal(nil,   Name.create("bar.CoM") <   "example.com")
    assert_equal(nil,   Name.create("bar.CoM") <=  "example.com")
    assert_equal(nil,   Name.create("bar.CoM") <=> "example.com")
    assert_equal(nil,   Name.create("bar.CoM") >=  "example.com")
    assert_equal(nil,   Name.create("bar.CoM") >   "example.com")

    assert_equal(nil,   Name.create("net.") <   "com")
    assert_equal(nil,   Name.create("net.") <=  "com")
    assert_equal(nil,   Name.create("net.") <=> "com")
    assert_equal(nil,   Name.create("net.") >=  "com")
    assert_equal(nil,   Name.create("net.") >   "com")

  end

  def test_txt_with_0_strs
    # Packet collected from the wild, it is non-conformant with DNS
    # specification, TXT record has zero strings, but should have 1 or more.
    d = "\000\000\204\000\000\000\000\005\000\000\000\000\002me\005local\000\000\001\200\001\000\000\000\360\000\004\300\250\003\003\005proxy\010_example\004_tcp\300\017\000!\200\001\000\000\000\360\000\010\000\000\000\000'\017\300\f\300$\000\020\200\001\000\000\000\360\000\000\t_services\a_dns-sd\004_udp\300\017\000\f\000\001\000\000\034 \000\002\300*\300*\000\f\000\001\000\000\034 \000\002\300$"

    m =  Resolv::DNS::Message.decode( d )

    assert_equal('',    m.answer[2][2].data)
    assert_equal([''],  m.answer[2][2].strings)
  end

  def txt_codec(*args)
    m = Resolv::DNS::Message.new
    m.add_answer('example.local', 0, Resolv::DNS::Resource::IN::TXT.new(*args))
#   pp m
    m = Resolv::DNS::Message.decode(m.encode)
    txt = m.answer[0][2]
#   pp txt
    txt
  end

  def test_txt_with_large_str
    # short or no strings
    txt = txt_codec()
    assert_equal('',   txt.data)
    assert_equal([''], txt.strings)

    txt = txt_codec('')
    assert_equal('',   txt.data)
    assert_equal([''], txt.strings)
    
    txt = txt_codec('s')
    assert_equal('s',   txt.data)
    assert_equal(['s'], txt.strings)
    
    txt = txt_codec('s', 'a', 'm')
    assert_equal('sam',           txt.data)
    assert_equal(['s', 'a', 'm'], txt.strings)

    s = '0' * 255

    # long strings
    txt = txt_codec(s)
    assert_equal(s,   txt.data)
    assert_equal([s], txt.strings)

    # long strings
    f = s + 'a'
    txt = txt_codec(f)
    assert_equal(f,   txt.data)
    assert_equal([s, 'a'], txt.strings)

    f = s + s
    txt = txt_codec(f)
    assert_equal(f,   txt.data)
    assert_equal([s, s], txt.strings)

    assert_raise(ArgumentError) { txt_codec(f, 'a') }
    assert_raise(ArgumentError) { txt_codec('a', f) }

  end


end

