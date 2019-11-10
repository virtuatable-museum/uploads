FactoryGirl.define do
  factory :empty_session, class: Arkaan::Authentication::Session do
    factory :session do
      token { Faker::Alphanumeric.unique.alphanumeric(20) }
    end
  end
end