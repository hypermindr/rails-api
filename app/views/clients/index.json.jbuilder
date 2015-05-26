json.array!(@clients) do |client|
  json.extract! client, :id, :name, :status, :apikey
  json.url client_url(client, format: :json)
end
