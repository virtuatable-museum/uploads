FactoryGirl.define do
  factory :empty_ruleset, class: Arkaan::Ruleset do
    factory :ruleset do
      name 'Dungeons and Dragons 4the Edition'
    end
  end
end