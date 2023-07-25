FactoryBot.define do
  factory :flight, class: Hash do
    type { "Boeing 737" }
    seats { { window: 25, aisle: 25, between_seats: 25 } }
    datetime { "2025-06-24T00:00:00Z" }
    origin { "Buenos Aires" }
    destination { "Madrid" }
    offer_duration { 1 }

    initialize_with { attributes }
  end
end