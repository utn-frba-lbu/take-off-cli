FactoryBot.define do
  factory :booking, class: Hash do
    user { "user" }
    flight_id { "22626a28-86e9-484b-ac9a-7e72cca3ab42" }
    seats { { window: 1, aisle: 1, between_seats: 0 } }

    initialize_with { attributes }
  end
end