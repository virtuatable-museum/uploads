FactoryGirl.define do
  factory :empty_campaign, class: Arkaan::Campaign do
    factory :campaign do
      title { Faker::Alphanumeric.unique.alphanumeric(20) }
      description { Faker::TvShows::BojackHorseman.quote }
      is_private true
      tags { [Faker::Movies::StarWars.planet] }
    end
  end
end