unless Rails.env.none?
  Mongoid.configure do |config|
    config.clients.default = {
      uri: DocytLib.config.mongodb.url
    }
    config.options = {
      raise_not_found_error: false
    }
  end
end