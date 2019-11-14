FactoryGirl.define do
  factory :empty_character, class: Arkaan::Campaigns::Character do
    factory :character do
      selected true
      name 'Saroumane'
      mime_type 'application/xml'
    end
  end
end