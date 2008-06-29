#/usr/local/bin/ruby
#/usr/bin/ruby

require 'test/unit'
begin
  require 'dnssd'
rescue LoadError => error
  #This is just in case you did not install, but want to test
  $:.unshift '../lib'
  $:.unshift '../ext'
  require 'dnssd'
end

include DNSSD

class Test_DNSSD < Test::Unit::TestCase

	def test_text_record
		tr = TextRecord.new
		tr["key"]="value"
		enc_str = ["key", "value"].join('=')
		enc_str = enc_str.length.chr << enc_str
		assert_equal(enc_str, tr.encode)

		# should raise type error
		assert_raise(TypeError) do
			tr_new = TextRecord.decode(:HEY)
		end
		tr_new = TextRecord.decode(enc_str)
		assert_equal(tr_new, tr)

		# new called with just a string should be
		# the same as decode.
		tr_new = TextRecord.new(enc_str)
		assert_equal(tr_new, tr)
	end

	def test_flags
		f = Flags.new()
		f.more_coming = true
		assert(f.more_coming?)
		assert_equal(Flags::MoreComing, f.to_i)
		f.shared = true
		assert(f.shared?)
		assert_equal(Flags::MoreComing | Flags::Shared, f.to_i)

		assert_equal(Flags.new(Flags::MoreComing | Flags::Shared), f.to_i)
		
		assert_same(true, f.add = true)
		assert(f.add?)
	end

	def test_browse
		# how to test?
	end
	
end

