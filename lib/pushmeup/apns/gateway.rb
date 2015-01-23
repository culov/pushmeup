require 'socket'
require 'openssl'

module Pushmeup::APNS
  class CertificateNotSetException < StandardError; end
  class CertificateFileNotFoundException < StandardError; end

  class Gateway
    HOST = 'gateway.sandbox.push.apple.com'
    PORT = 2195
    RETRIES = 3

    @@mutex = Mutex.new

    def initialize(options={})
      @options = options
      check_options
    end

    def check_options
      raise CertificateNotSetException, "The path to your pem file is not set. (APNS.pem = /path/to/cert.pem)" unless pem
      raise CertificateFileNotFoundException, "The path to your pem file does not exist!" unless File.exist?(pem)
    end

    def host
      @host ||= @options[:host] || Pushmeup.configuration.apns_host || HOST
    end

    def port
      @port ||= @options[:port] || Pushmeup.configuration.apns_port || PORT
    end


    # openssl pkcs12 -in mycert.p12 -out client-cert.pem -nodes -clcerts
    # Caches pem file in memory
    def pem
      @pem ||= @options[:pem] || Pushmeup.configuration.apns_pem
    end

    def pem_file
      @pem_file ||= File.read(pem)
    end

    def pass
      @pass ||= @options[:pass] || Pushmeup.configuration.apns_pass
    end

    def persistent
      @persistent ||= @options[:persistent]
    end

    #Send notification
    def send_notification(device_token, message)
      n = Pushmeup::APNS::Notification.new(device_token, message)
      send_notifications([n])
    end

    def send_notifications(notifications)
      @@mutex.synchronize do
        with_connection do
          notifications.each do |n|
            @ssl.write(n.packaged_notification)
          end
        end
      end
    end

    # You should connect regularly with the feedback service and fetch the current list of those
    # devices that have repeatedly reported failed-delivery attempts. Then stop sending
    # notifications to the devices associated with those apps. See The Feedback Service for
    # more information. https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/CommunicatingWIthAPS.html#//apple_ref/doc/uid/TP40008194-CH101-SW3
    def feedback
      fhost         = HOST.gsub('gateway','feedback')
      fsock         = TCPSocket.new(fhost, 2196)
      fssl          = OpenSSL::SSL::SSLSocket.new(fsock, context)
      fssl.connect

      apns_feedback = []

      while line = fssl.read(38)   # Read lines from the socket
        line.strip!
        f = line.unpack('N1n1H140')
        apns_feedback << { :timestamp => Time.at(f[0]), :token => f[2] }
      end

      fssl.close
      fsock.close

      apns_feedback
    end

    def close
      @@mutex.synchronize do
        kill_connection
      end
    end

    def connection_unavailable?
      # Do not use memoized methods for objects here because
      # 'closed?' returns false on new socket objects even before
      # connect is called. Therefore, the nil check is very important.
      @ssl.nil? || @sock.nil? || @ssl.closed? || @sock.closed?
    end

    def sock
      @sock ||= TCPSocket.new(host, port)
    end

    def context
      return @context if @context
      @context ||= OpenSSL::SSL::SSLContext.new
      @context.cert = OpenSSL::X509::Certificate.new(pem_file)
      @context.key  = OpenSSL::PKey::RSA.new(pem_file, pass)
      @context
    end

    def ssl
      return @ssl if @ssl
      @ssl ||= OpenSSL::SSL::SSLSocket.new(sock, context)
      @ssl
    end

    def kill_connection
      @ssl.close  if @ssl && !@ssl.closed?
      @sock.close if @sock && !@sock.closed?
    ensure
      @ssl = nil # Must set to nil so we create a new socket after closing
      @sock = nil
    end

    #######
    private
    #######

    def with_connection
      attempts = 1

      begin
        # If no @ssl is created or if @ssl is closed we need to start it
        if connection_unavailable?
          ssl.connect
        end

        yield

      rescue StandardError, Errno::EPIPE
        raise unless attempts < RETRIES
        kill_connection
        attempts += 1
        retry
      end

      # Only close if not persistent
      unless persistent
        kill_connection
      end
    end

  end

end
