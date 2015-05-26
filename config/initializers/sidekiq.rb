Sidekiq.configure_server do |config|
  config.failures_max_count = false
  config.redis = { url: "redis://#{Settings[:sidekiq][:redis]}/12", namespace: Rails.env }
end

Sidekiq.configure_client do |config|
  config.redis = { url: "redis://#{Settings[:sidekiq][:redis]}/12", namespace: Rails.env }
end
