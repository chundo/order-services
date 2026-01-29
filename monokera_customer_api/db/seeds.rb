# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding customers..."

customers_data = [
  { customer_name: "Juan García", email: "juan.garcia@example.com", address: "Calle Principal 123, Madrid", orders_count: 5 },
  { customer_name: "María López", email: "maria.lopez@example.com", address: "Avenida Central 456, Barcelona", orders_count: 3 },
  { customer_name: "Carlos Rodríguez", email: "carlos.rodriguez@example.com", address: "Plaza Mayor 789, Sevilla", orders_count: 8 },
  { customer_name: "Ana Martínez", email: "ana.martinez@example.com", address: "Calle Secundaria 321, Valencia", orders_count: 2 },
  { customer_name: "Pedro Sánchez", email: "pedro.sanchez@example.com", address: "Boulevard Norte 654, Bilbao", orders_count: 0 },
  { customer_name: "Laura Fernández", email: "laura.fernandez@example.com", address: "Paseo del Prado 987, Madrid", orders_count: 12 },
  { customer_name: "Diego Hernández", email: "diego.hernandez@example.com", address: "Calle del Sol 147, Málaga", orders_count: 1 },
  { customer_name: "Sofía González", email: "sofia.gonzalez@example.com", address: "Avenida Libertad 258, Zaragoza", orders_count: 4 },
  { customer_name: "Miguel Torres", email: "miguel.torres@example.com", address: "Plaza España 369, Murcia", orders_count: 6 },
  { customer_name: "Elena Ramírez", email: "elena.ramirez@example.com", address: "Calle Luna 741, Palma", orders_count: 0 }
]

customers_data.each do |customer_data|
  Customer.find_or_create_by!(email: customer_data[:email]) do |customer|
    customer.customer_name = customer_data[:customer_name]
    customer.address = customer_data[:address]
    customer.orders_count = customer_data[:orders_count]
  end
end

puts "Created #{Customer.count} customers."
