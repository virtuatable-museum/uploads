FactoryGirl.define do
  factory :empty_account, class: Arkaan::Account do
    factory :account do
      username { Faker::Internet.unique.username(5..10) }
      password 'password'
      password_confirmation 'password'
      email { Faker::Internet.unique.safe_email }
      lastname { Faker::Name.last_name }
      firstname { Faker::Name.first_name }
    end
  end
end