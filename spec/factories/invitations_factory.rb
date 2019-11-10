FactoryGirl.define do
  factory :empty_invitation, class: Arkaan::Campaigns::Invitation do
    factory :invitation do
      [:accepted, :pending, :refused, :request, :left, :expelled, :blocked, :ignored].each do |tmp_status|
        factory :"#{tmp_status.to_s}_invitation" do
          status tmp_status
        end
      end
    end
  end
end