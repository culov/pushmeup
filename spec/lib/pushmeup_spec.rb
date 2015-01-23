require 'spec_helper'

describe Pushmeup do
  describe "APNS" do

    context "you don't set a pem file to be used" do
      it "should raise an exception when it starts" do
        expect{ Pushmeup::APNS::Gateway.new}.to raise_error(Pushmeup::APNS::CertificateNotSetException)
      end
    end

    context "you set a pem path that dones't exist" do
      it "should raise an exception when it starts" do
        expect{ Pushmeup::APNS::Gateway.new(pem: "wroooong.pem")}.to raise_error(Pushmeup::APNS::CertificateFileNotFoundException)
      end
    end

    context "you set a pem file to be used" do
      let(:pem_path) { File.expand_path(File.join("..", "..", "fixtures", "dummy.pem"), __FILE__) }
      let(:apns) {Pushmeup::APNS::Gateway.new(pem: pem_path)}

      it "should not forget the APNS default parameters" do
        expect(apns.host).to eq("gateway.sandbox.push.apple.com")
        expect(apns.port).to eq(2195)
        expect(apns.pem).to eq(pem_path)
        expect(apns.pass).to be_nil
      end

      describe "Notifications" do

        describe "#==" do

          it "should properly equate objects without caring about object identity" do
            a = Pushmeup::APNS::Notification.new("123", {:alert => "hi"})
            b = Pushmeup::APNS::Notification.new("123", {:alert => "hi"})
            expect(a).to eq(b)
          end

        end

      end

    end
  end

  describe "GCM" do
    let(:gcm) {Pushmeup::APNS::Gateway.new}

    describe "Notifications" do

      before do
        @options = {:data => "dummy data"}
      end

      it "should allow only notifications with device_tokens as array" do
        n = Pushmeup::GCM::Notification.new("id", @options)
        expect(n.device_tokens.class).to eq(Array)

        n.device_tokens = ["a" "b", "c"]
        expect(n.device_tokens.class).to eq(Array)

        n.device_tokens = "a"
        expect(n.device_tokens.class).to eq(Array)
      end

      it "should allow only notifications with data as hash with :data root" do
        n = Pushmeup::GCM::Notification.new("id", { :data => "data" })

        expect(n.data.class).to eq(Hash)
        expect(n.data).to eq({:data => "data"})

        n.data = {:a => ["a", "b", "c"]}
        expect(n.data.class).to eq(Hash)
        expect(n.data).to eq({:a => ["a", "b", "c"]})

        n.data = {:a => "a"}
        expect(n.data.class).to eq(Hash)
        expect(n.data).to eq({:a => "a"})
      end

      describe "#==" do

        it "should properly equate objects without caring about object identity" do
          a = Pushmeup::GCM::Notification.new("id", { :data => "data" })
          b = Pushmeup::GCM::Notification.new("id", { :data => "data" })
          expect(a).to eq(b)
        end

      end

    end
  end
end
