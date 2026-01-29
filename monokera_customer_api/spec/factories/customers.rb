FactoryBot.define do
  factory :customer do
    customer_name { Faker::Name.name }
    email { Faker::Internet.unique.email }
    address { Faker::Address.full_address }
    orders_count { 0 }

    trait :with_orders do
      orders_count { Faker::Number.between(from: 1, to: 10) }
    end

    trait :without_address do
      address { nil }
    end
  end
end
