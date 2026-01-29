# frozen_string_literal: true

FactoryBot.define do
  factory :order do
    customer_id { Faker::Number.between(from: 1, to: 1000) }
    product_name { Faker::Commerce.product_name }
    quantity { Faker::Number.between(from: 1, to: 10) }
    price { Faker::Commerce.price(range: 10.0..500.0) }
    status { "pending" }

    trait :processing do
      status { "processing" }
    end

    trait :completed do
      status { "completed" }
    end

    trait :cancelled do
      status { "cancelled" }
    end
  end
end
