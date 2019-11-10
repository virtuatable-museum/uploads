FactoryGirl.define do
  factory :empty_permission, class: Arkaan::Campaigns::Files::Permission do
    factory :permission do
      enum_level :read
    end
  end
end