FactoryBot.define do
  factory :alert, class: Hash do
    user { "user" }
    origin { "Buenos Aires" }
    destination { "Madrid" }
    webhook_uri { "localhost:8080" }

    trait :with_date do
      date { "2025-06-24" }
    end

    trait :with_year_month do
      year { 2025 }
      month { 6 }
    end

    initialize_with { attributes }
  end
end