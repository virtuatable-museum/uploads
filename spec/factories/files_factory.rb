FactoryGirl.define do
  factory :empty_file, class: Arkaan::Campaigns::Files::Document do
    factory :file do
      mime_type 'image/jpg'
      name { Faker::File.unique.file_name }
      size { Faker::Number.between(1, 999) }
    end
  end
end