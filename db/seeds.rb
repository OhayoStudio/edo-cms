# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Categories
[
  { name: "Sartorial",         description: "fashion",                                                                                    slug: "sartorial",        position: 1,   featured: false, status: nil,      meta_title: "",          meta_description: "",                                                                    parent_id: nil },
  { name: "Tech",              description: "Tech",                                                                                       slug: "tech",             position: nil, featured: false, status: nil,      meta_title: "",          meta_description: "",                                                                    parent_id: nil },
  { name: "Books",             description: "My books",                                                                                   slug: "books",            position: nil, featured: false, status: nil,      meta_title: "",          meta_description: "",                                                                    parent_id: nil },
  { name: "Beverages",         description: "Other than water",                                                                           slug: "beverages",        position: nil, featured: false, status: nil,      meta_title: "",          meta_description: "",                                                                    parent_id: nil },
  { name: "Furnitures",        description: "Furnitures",                                                                                 slug: "furnitures",       position: nil, featured: false, status: nil,      meta_title: "",          meta_description: "",                                                                    parent_id: nil },
  { name: "Watches",           description: "Watches",                                                                                    slug: "watches",          position: nil, featured: false, status: "active", meta_title: "watches",   meta_description: "watches",                                                             parent_id: nil },
  { name: "Music instruments", description: "Music instruments",                                                                          slug: "music-instruments",position: nil, featured: false, status: nil,      meta_title: "",          meta_description: "",                                                                    parent_id: nil },
  { name: "Audiophile",        description: "Audiophile",                                                                                 slug: "audiophile",       position: nil, featured: false, status: nil,      meta_title: "",          meta_description: "",                                                                    parent_id: nil },
  { name: "Mobility",          description: "Mobility",                                                                                   slug: "mobility",         position: nil, featured: false, status: "active", meta_title: "Mobility",  meta_description: "Mobility",                                                            parent_id: nil },
  { name: "Arranged Sounds",   description: "Arranged Sounds",                                                                            slug: "arranged-sounds",  position: nil, featured: false, status: nil,      meta_title: "",          meta_description: "",                                                                    parent_id: nil },
  { name: "Places",            description: "Cities / Travel",                                                                            slug: "places",           position: nil, featured: false, status: "active", meta_title: "places",    meta_description: "places, cities, travel",                                              parent_id: nil },
  { name: "Wellness",          description: "Wellness, Sports, Health",                                                                   slug: "wellness",         position: nil, featured: false, status: "active", meta_title: "Wellness",  meta_description: "Wellness, Sports, Health",                                            parent_id: nil },
  { name: "Bicycles",          description: "Bicycles: Aluminium, Steel, Chromoly, Carbon, Tatanium, frames, parts, brands",              slug: "bicycles",         position: nil, featured: false, status: "active", meta_title: "biycles",   meta_description: "Bicycles, Aluminium, Steel, Chromoly, Carbon, Tatanium, frames, parts, brands", parent_id: "Mobility" },
].each do |attrs|
  parent_name = attrs.delete(:parent_id)
  parent = parent_name ? Category.find_by!(name: parent_name) : nil
  Category.find_or_create_by!(slug: attrs[:slug]) do |c|
    c.assign_attributes(attrs.merge(parent_id: parent&.id))
  end
end

# Admin user — single account for site owner
# Set ADMIN_EMAIL and ADMIN_PASSWORD env vars before running db:seed
if User.count.zero?
  email    = ENV.fetch("ADMIN_EMAIL",    "jerome@ohayostudio.com")
  password = ENV.fetch("ADMIN_PASSWORD", SecureRandom.hex(16))
  User.create!(email_address: email, password: password, password_confirmation: password)
  puts "Admin user created: #{email}"
  puts "Password: #{password}" if ENV["ADMIN_PASSWORD"].blank?
end
