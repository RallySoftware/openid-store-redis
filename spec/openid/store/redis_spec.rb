require 'spec_helper'
require 'securerandom'
require 'openid/association'
require 'openid/store/nonce'
Nonce = OpenID::Nonce

describe OpenID::Store::Redis do
  let(:redis) { MockRedis.new }
  let(:url) { 'https://example.com/' + SecureRandom.base64 }
  let(:handle) { SecureRandom.base64 }

  subject { OpenID::Store::Redis.new(redis) }

  describe '#get_association' do
    it 'returns nil when association does not exist' do
      subject.get_association(url).should be_nil
    end

    it 'returns nil when association with handle does not exist' do
      server_url = 'test/url'
      handle = 'test/handle'
      subject.get_association(url, handle).should be_nil
    end

    it 'returns association when exists' do
      assn = association(0)
      redis.set('openid-store:a:' + url, Marshal.dump(assn))
      subject.get_association(url).handle.should eql assn.handle
      subject.get_association(url).secret.should eql assn.secret
    end

    it 'returns association with handle' do
      assoc = association(0)
      redis.set('openid-store:a:' + url + ":" + handle, Marshal.dump(assoc))
      subject.get_association(url, handle).handle.should eql assoc.handle
      subject.get_association(url, handle).secret.should eql assoc.secret
    end
  end

  describe '#store_association' do
    it 'stores association to redis' do
      assoc = association(0)
      serialized = Marshal.dump(assoc)
      subject.store_association(url, assoc)
      redis.get('openid-store:a:' + url).should eql(serialized)
    end

    it 'stores with handle' do
      assoc = association(0)
      serialized = Marshal.dump(assoc)
      subject.store_association(url, assoc)
      redis.get('openid-store:a:' + url + ':' + assoc.handle).should eql(serialized)
    end

    it 'expires the association after lifetime' do
      assoc = association(0)
      subject.store_association(url, assoc)
      ttl = redis.ttl('openid-store:a:' + url + ':' + assoc.handle)
      ttl.should eql(assoc.lifetime)
    end
  end

  describe '#remove_association' do
    let(:assoc) { association(0) }
    before :each do
      redis.set('openid-store:a:' + url + ":" + assoc.handle, Marshal.dump(assoc))
      redis.set('openid-store:a:' + url, Marshal.dump(assoc))
    end

    it 'removes association from redis' do
      subject.remove_association(url, assoc.handle)
      redis.get('openid-store:a:' + url + ":" + assoc.handle).should be_nil
      redis.get('openid-store:a:' + url).should be_nil
    end

    it 'does not remove when handles do not match' do
      subject.remove_association(url, assoc.handle  + 'fail')
      redis.get('openid-store:a:' + url + ":" + assoc.handle).should_not be_nil
    end

    it 'returns true when data is removed' do
      subject.remove_association(url, assoc.handle).should be(true)
    end

    it 'returns false when data is not removed' do
      subject.remove_association(url + 'fail', assoc.handle).should be(false)
    end
  end

  describe '#use_nonce' do
    it 'allows nonce to be used once' do
      timestamp, salt = Nonce::split_nonce(Nonce::mk_nonce)
      subject.use_nonce(url, timestamp.to_i, salt).should be_truthy
    end

    it 'does not allow multiple uses of nonce' do
      timestamp, salt = Nonce::split_nonce(Nonce::mk_nonce)
      subject.use_nonce(url, timestamp.to_i, salt)
      subject.use_nonce(url, timestamp.to_i, salt).should be_falsey
    end

    it 'creates nonce if time is within skew' do
      now = Time.now
      timestamp = now.to_f + OpenID::Nonce.skew - 1
      subject.use_nonce(url, timestamp, 'salt').should be_truthy
    end

    it 'returns false if time is beyond skew' do
      now = Time.now
      timestamp = now.to_f + OpenID::Nonce.skew + 1
      subject.use_nonce(url, timestamp, 'salt').should be_falsey
    end

    it 'removes nonce from redis after skew timeout' do
      ts, salt = Nonce::split_nonce(Nonce::mk_nonce)
      subject.use_nonce(url, ts.to_i, salt)
      ttl = redis.ttl('openid-store:n:' + url + ':' + ts.to_s + ':' + salt)
      ttl.should eql(OpenID::Nonce.skew + 5)
    end
  end

  describe '#cleanup_nonces' do
    before :each do
      ts, salt = Nonce::split_nonce(Nonce::mk_nonce)
      subject.use_nonce(url, ts.to_i, salt)
    end

    it 'removes nonces from redis' do
      subject.cleanup_nonces
      redis.keys.should be_empty
    end

    it 'leaves association data' do
      redis.set 'openid-store:a:url', 'testtest'
      subject.cleanup_nonces
      redis.keys.size.should eq(1)
    end
  end

  describe '#cleanup_associations' do
    before :each do
      assoc = association(0)
      redis.set('openid-store:a:' + url + ":" + assoc.handle, Marshal.dump(assoc))
    end

    it 'removes association data' do
      subject.cleanup_associations
      redis.keys.should be_empty
    end

    it 'leaves nonce data' do
      ts, salt = Nonce::split_nonce(Nonce::mk_nonce)
      subject.use_nonce(url, ts.to_i, salt)
      subject.cleanup_associations
      redis.keys.size.should eq(1)
    end
  end

  describe '#cleanup' do
    before :each do
      ts, salt = Nonce::split_nonce(Nonce::mk_nonce)
      subject.use_nonce(url, ts.to_i, salt)
      assoc = association(0)
      redis.set('openid-store:a:' + url + ":" + assoc.handle, Marshal.dump(assoc))
    end

    it 'removes redis store data' do
      subject.cleanup
      redis.keys.should be_empty
    end

    it 'leaves other data around' do
      redis.set 'something-else', 'is still there'
      subject.cleanup
      redis.get('something-else').should == 'is still there'
    end
  end
end

def association(issued, lifetime=600)
   OpenID::Association.new(SecureRandom.hex(128),
                           SecureRandom.base64(20),
                           Time.now + issued,
                           lifetime,
                           'HMAC-SHA1')
end
