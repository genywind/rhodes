require 'typhoeus'
require_relative 'configuration'
require_relative 'subscriber'

module RhoDevelopment
  class DeviceFinder
    def run
      print "Discovering... ".primary
      subscribers = self.serialDiscovery
      if subscribers.empty?
        puts 'no devices found'.warning
      else
        puts 'done'.success
        puts subscribers.to_s.info
        print 'Storing subscribers...'.primary
        Configuration::store_subscribers(subscribers)
        puts 'done'.success
      end
    end

    def parallelDiscovery
      subscribers = []
      mask = Configuration::own_ip_address.split('.')[0, 3].join('.')

      hydra = Typhoeus::Hydra.hydra
      1.upto(254) { |each|
        url = URI("http://#{mask}.#{each}:37579/development/get_info")
        request = Typhoeus::Request.new(url)
        request.options['timeout'] = 5
        request.on_complete do |response|
          if response.code == 200
            data = JSON.parse(response.body)
            subscriber = {}
            subscriber['uri'] = "#{data['ip']}:#{data['port']}"
            subscriber['name'] = data['deviceFriendlyName']
            subscriber['platform'] = data['platform']
            subscriber['application'] = data['applicationName']
            subscribers << subscriber
          end
        end
        hydra.queue request
      }
      hydra.run


    end

    def serialDiscovery
      subscribers = []
      mask = Configuration::own_ip_address.split('.')[0, 3].join('.')
      1.upto(254) { |each|
        url = URI("http://#{mask}.#{each}:37579/development/get_info")
        begin
          http = Net::HTTP.new(url.host, url.port)
          http.open_timeout = 0.5
          http.start() { |http|
            response = http.get(url.path)
            puts "#{url} answered: #{response.body}".info
            data = JSON.parse(response.body)
            subscriber = {}
            subscriber['uri'] = "#{data['ip']}:#{data['port']}"
            subscriber['name'] = data['deviceFriendlyName']
            subscriber['platform'] = data['platform']
            subscriber['application'] = data['applicationName']
            subscribers << subscriber
          }
        rescue Errno::ECONNREFUSED, Net::OpenTimeout => e
          #TODO may be it is necessary remove subscriber from list?
          puts "#{url} is not accessible. error: #{e.class}".info
        end
      }
      return subscribers
    end
  end

end