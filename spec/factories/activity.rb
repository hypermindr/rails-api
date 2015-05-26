FactoryGirl.define do
    factory :activity do
        external_user_id '10001'
        activity "read"
        ip "8.8.8.8"
        anonymous false
    end
end