FactoryGirl.define do
  factory :client do
    name "GoodNoows"
    domain_name "goodnoows.com"
    status "active"
    feed_url "http://goodnoows.local/api/v1.0/?a=getrecentarticles&aid={product_id}"
  end

end

