FactoryGirl.define do
  factory :empty_tag, class: Arkaan::Campaigns::Tag do
    factory :tag do
      content 'test_tag'
      count 1
    end
  end
end