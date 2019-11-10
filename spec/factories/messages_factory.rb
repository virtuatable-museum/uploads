FactoryGirl.define do
  factory :empty_message, class: Arkaan::Campaigns::Message do
    factory :message do
      enum_type :text
      data(content: 'test messages')
    end
  end
end