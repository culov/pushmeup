# Pushmeup

A gem for various push notification services.

## Goals

Pushmeup is an attempt to create an push notifications center that could send push to devices like:

- Android
- iOS
- Mac OS X
- Windows Phone
- And many others

Currently we have only support for ``iOS``, ``Android`` and ``Kindle Fire`` but we are planning code for more plataforms.

## Installation

    $ gem install pushmeup

or add to your ``Gemfile``

    gem 'pushmeup'

and install it with

    $ bundle install

## APNS (Apple iOS)

### Configure

1. In Keychain access export your certificate and your private key as a ``p12``.

  ![Keychain Access](https://raw.github.com/NicosKaralis/pushmeup/master/Keychain Access.jpg)

2. Run the following command to convert the ``p12`` to a ``pem`` file

        $ openssl pkcs12 -in cert.p12 -out cert.pem -nodes -clcerts

3. After you have created your ``pem`` file you can create your gateway

```ruby
gateway = Pushmeup::APNS::Gateway.new(pem: '/path/to/pem/file')

# or, in the case that your certificate has a password:
gateway = Pushmeup::APNS::Gateway.new(pem: '/path/to/pem/file', pass: 'password')

# Only the pem option is mandatory, the other use default values
gateway = Pushmeup::APNS::Gateway.new(pem: '/path/to/pem/file',
                                      host: 'gateway.push.apple.com',
                                      port: 2195)
```

4. Default options can be configured using an initializer:

```ruby
Pushmeup.configure do |config|
  # default host and port are shown below
  config.apns_host = "gateway.sandbox.push.apple.com"
  config.apns_port = "2195"
  config.apns_pem  = "/path/to/pem_file"
  config.apns_pass = "password"
end
```
Specifying any of the above options when creating a new gateway will override any options set in an initializer. In this way, you can as many different gateways as you need to or simply set all values in the initializer.

### Usage

#### Sending a single notification:

```ruby
device_token = '123abc456def'
gateway.send_notification(device_token, 'Hello iPhone!' )
gateway.send_notification(device_token, :alert => 'Hello iPhone!',
                                        :badge => 1,
                                        :sound => 'default',
                                        :category => 'cat1',
                                        :content_available => false)
```

#### Sending multiple notifications

```ruby
device_token = '123abc456def'
n1 = Pushmeup::APNS::Notification.new(device_token, 'Hello iPhone!' )
n2 = Pushmeup::APNS::Notification.new(device_token, :alert => 'Hello iPhone!',
                                                    :badge => 1,
                                                    :sound => 'default',
                                                    :category => 'cat1',
                                                    :content_available => true)
gateway.send_notifications([n1, n2])
```
When sending multiple notifications, they will all be sent on a single conncetion in order to improve reliability with APNS servers.

#### Persistent Connections
Another way to send multiple notifications is to send notifications in a thread safe, persistent connection.

```ruby
# create a gateway with a persistent connection
gateway = Pushmeup::APNS::Gateway.new(persistent: true)

device_token = '123abc456def'

# Send single notifications
gateway.send_notification(device_token, 'Hello iPhone!' )
gateway.send_notification(device_token, :alert => 'Hello iPhone!',
                                        :badge => 1,
                                        :sound => 'default',
                                        :category => 'cat1')

# Or send multiple notifications
n1 = Pushmeup::APNS::Notification.new(device_token, 'Hello iPhone!' )
n2 = Pushmeup::APNS::Notification.new(device_token, :alert => 'Hello iPhone!',
                                                    :badge => 1,
                                                    :sound => 'default')
gateway.send_notifications([n1, n2])

...

gateway.close #in case you want to close the connection
```


#### Sending additional information

```ruby
gateway.send_notification(device_token, :alert => 'Hello iPhone!',
                                        :badge => 1,
                                        :sound => 'default',
                                        :other => {
                                          :sent => 'with apns gem',
                                          :custom_param => "value"
                                        })
```

this will result in a payload like this:

    {"aps":{"alert":"Hello iPhone!","badge":1,"sound":"default"},"sent":"with apns gem", "custom_param":"value"}

### Resources
For more inforamtion about device tokens and other APNS configuration, you are encouraged to visit the [iOS Developer Library](https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/IPhoneOSClientImp.html#//apple_ref/doc/uid/TP40008194-CH103-SW1)


## GCM (Google Cloud Messaging)

### Configure

As with APNS, you can set default configuration options for all gateways in an initializer:
```ruby
Pushmeup.configure do |config|
  config.gcm_key   = "12345" # this is the apiKey obtained from https://code.google.com/apis/console/
  config.gcm_host  = "https://android.googleapis.com/gcm/send" # default value
end
```

### Usage

#### Sending a single notification:

```ruby

# Create your gateway
gateway = Pushmeup::GCM::Gateway.new

# can be an string or an array of strings containing the regIds of the devices you want to send
destinations = ["device1", "device2", "device3"]

# must be an hash with all values you want inside you notification
data = {:key => "value", :key2 => ["array", "value"]}

# Empty notification
gateway.send_notification( destinations )

# Notification with custom information
gateway.send_notification( destination, data )

# Notification with custom information and parameters
gateway.send_notification( destination, data, :collapse_key => "placar_score_global",
                                              :time_to_live => 3600,
                                              :delay_while_idle => false )
```

#### Sending multiple notifications:

```ruby
destination1 = "device1"
destination2 = ["device2"]
destination3 = ["device1", "device2", "device3"]

# must be an hash with all values you want inside you notification
data1 = {:key => "value", :key2 => ["array", "value"]}

# options for the notification
options1 = {:collapse_key => "placar_score_global", :time_to_live => 3600, :delay_while_idle => false}

n1 = Pushmeup::GCM::Notification.new(destination1, data1, options1)
n2 = Pushmeup::GCM::Notification.new(destination2, data2)
n3 = Pushmeup::GCM::Notification.new(destination3, data3, options2)

gateway = Pushmeup::GCM::Gateway.new

# In this case, every notification has his own parameters
gateway.send_notifications( [n1, n2, n3] )

```

### (Optional) You can add multiple keys for GCM

You can use multiple keys to send notifications, to do it just do this changes in the code

```ruby
# the ``:key1`` and the ``:key2`` can be any object, they can be the projectID, the date, the version, doesn't matter.
# The only restrain is: they need to be valid keys for a hash.
gateway = Pushmeup::GCM::Gateway.new(:gcm_key => { :key1 => "123abc456def", :key2 => "456def123abc" })

destination = "device1"
data = {:key => "value", :key2 => ["array", "value"]}

# For single notification
gateway.send_notification( destination, data, :identity => :key1 )

gateway.send_notification( destination, data, :collapse_key => "placar_score_global",
                                              :time_to_live => 3600,
                                              :delay_while_idle => false,
                                              :identity => :key2 )

# For multiple notifications
options2 = {..., :identity => :key2}
n1 = Pushmeup::GCM::Notification.new(destination, data, {:identity => :key2})
n2 = Pushmeup::GCM::Notification.new(destination, data, :identity => :key1)

# In this case, every notification has its own parameters, options and key
gateway.send_notifications( [n1, n2] )
```

### Resources
For more information on GCM and other parameters please rever to the android documentation: [GCM | Android Developers](http://developer.android.com/guide/google/gcm/gcm.html#request)


## FIRE (Amazon Messaging)

### Configure

You can set default configuration options for all gateways in an initializer:

```ruby
Pushmeup.configure do |config|
  # this is the Client ID obtained from your Security Profile Management on amazon developers
  config.fire_client_id      = "12345"
  # this is the Client Secret obtained from your Security Profile Management on amazon developers
  config.fire_client_secret  = "abcdef"
end
```

### Usage

#### Sending a single notification:

```ruby
gateway = Pushmeup::Fire::Gateway.new

# can be an string or an array of strings containing the regId of the device you want to send
destination = "tydgfhewgnwe37586329586ejthe93053th346hrth3t"

# must be an hash with all values you want inside you notification, strings only, no arrays
data = {:key => "value", :key2 => "some value2"}

# Notification with custom information
gateway.send_notification( destination, data )

# Notification with custom information and parameters
gateway.send_notification( destination, data, :consolidationKey => "placar_score_global",
                                              :expiresAfter => 3600)

```

#### Sending multiple notifications:

```ruby
gateway = Pushmeup::Fire::Gateway.new

destination1 = "device1"
destination2 = ["device2"]
destination3 = ["device1", "device2", "device3"]

# must be an hash with all values you want inside you notification
data1 = {:key => "value", :key2 => ["array", "value"]}

# options for the notification
options1 = {:consolidationKey => "placar_score_global", :expiresAfter => 3600}

n1 = Pushmeup::FIRE::Notification.new(destination1, data1, options1)
n2 = Pushmeup::FIRE::Notification.new(destination2, data2)
n3 = Pushmeup::FIRE::Notification.new(destination3, data3, options2)

# In this case, every notification has his own parameters
gateway.send_notifications( [n1, n2, n3] )
```
### Resources
For more information on Amazon messaging, please check the following documentation: [Amazon Messaging | Developers](https://developer.amazon.com/public/apis/engage/device-messaging/tech-docs/06-sending-a-message#Request Format)

## Status

#### Build Status
[![Build Status](https://travis-ci.org/NicosKaralis/pushmeup.png?branch=master)](https://travis-ci.org/NicosKaralis/pushmeup)
[![Code Climate](https://codeclimate.com/github/NicosKaralis/pushmeup.png)](https://codeclimate.com/github/NicosKaralis/pushmeup)

#### Dependency Status [![Dependency Status](https://gemnasium.com/NicosKaralis/pushmeup.png?travis)](https://gemnasium.com/NicosKaralis/pushmeup)

## Contributing

We would be very pleased if you want to help us!

Currently we need a lot of testing so if you are good at writing tests please help us

## License

Pushmeup is released under the MIT license:

http://www.opensource.org/licenses/MIT


[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/NicosKaralis/pushmeup/trend.png)](https://bitdeli.com/free "Bitdeli Badge")
