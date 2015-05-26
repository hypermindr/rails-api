FactoryGirl.define do
  factory :product do
    external_id "176687414"
    date 1.day.ago
    url 'http://wsj.com/hypermindr-shares-hit-1000-usd'
    title 'hypermindR shares hit 1000 USD'
    short_content 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.'
    source 'WSJ'
    category 'startups'
    language 'english'
    full_content 'Lorem ipsum dolor sit ... amet, consectetur — adipiscing elit. Vestibulum leo sapien, imperdiet vitae. Lorem ipsum elit vestibulum leo sapien ipsum.'
  end
end