# workers 2
# preload_app!

threads 5, 5

environment ENV.fetch("RAILS_ENV") { "development" }

ssl_bind '0.0.0.0', ENV.fetch('PUMA_PORT') { '3000' }, {
    key: 'config/ssl/server.key',
    cert: 'config/ssl/server.crt'
}