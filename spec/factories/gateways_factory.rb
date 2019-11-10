FactoryGirl.define do
  factory :empty_gateway, class: Arkaan::Monitoring::Gateway do
    factory :gateway do
      url { Faker::Internet.unique.url }
      token 'test_token'
    end
  end
end