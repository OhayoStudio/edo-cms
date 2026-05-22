# Demo content for a fresh edo-cms install.
#
# Run with:
#   SEED_DEMO_CONTENT=1 bin/rails db:seed
# Or directly:
#   bin/rails runner db/seeds/demo.rb
#
# Idempotent: skips anything that already exists. Safe to re-run.
#
# Produces:
#   - 1 Author (Demo Writer)
#   - 1 Category (Stories)
#   - 5 Articles with solid-color featured images
#   - 5 Videos with real YouTube thumbnails from the official Beatles channel
#   - Story rows for each so they appear on the homepage

require "open-uri"
require "mini_magick"

puts "== Demo seed =="

author = Author.find_or_create_by!(email: "demo@example.com") do |a|
  a.first_name = "Demo"
  a.last_name  = "Writer"
  a.role       = :writer
end
puts "  author: #{author.full_name}"

category = Category.find_or_create_by!(name: "Stories") do |c|
  c.description = "Demo stories for a fresh edo-cms install."
end
puts "  category: #{category.name}"

# ─── Articles ────────────────────────────────────────────────
articles = [
  [ "First light over the harbour town",      "steelblue"      ],
  [ "On taking the slow train to nowhere",    "darkolivegreen" ],
  [ "Notes from a quiet workshop",            "sienna"         ],
  [ "The way the river bends in autumn",      "slategray"      ],
  [ "Three things I learned this week",       "indianred"      ]
]

articles.each_with_index do |(title, color), i|
  next if Article.exists?(title: title)

  path = Rails.root.join("tmp/demo_story_#{i}.png")
  MiniMagick::Tool::Convert.new do |c|
    c.size "1200x675"
    c << "xc:#{color}"
    c << path.to_s
  end

  a = Article.new(
    title:        title,
    excerpt:      "An example article seeded by db/seeds/demo.rb to give a fresh site some homepage content.",
    content:      "<p>Body text for #{title}. Replace this with your own content from /admin/articles.</p>",
    reading_time: 3,
    status:       :published,
    published_at: (i + 1).days.ago,
    author:       author,
    category:     category
  )
  a.featured_image.attach(io: File.open(path), filename: "demo_story_#{i}.png", content_type: "image/png")
  a.save!
  Story.find_or_create_by(storyable: a).update_columns(
    slug:         a.slug,
    is_published: true,
    published_at: a.published_at,
    is_top:       (i == 0)
  )
  puts "  article: #{title}"
end

# ─── Videos (Beatles official channel — real video IDs) ──────
videos = [
  [ "MhqtpH-tAGA", "Two different days, two great songs",                                "#TheBeatles #PaulMcCartney #JohnLennon" ],
  [ "t9ifeEUjLyg", "Imagine if that is how Paul really spoke",                           "#TheBeatles #YellowSubmarine" ],
  [ "IUzVDkJ2qd4", "Do not let The Beatles and Billy Preston down",                      "#TheBeatles #BillyPreston" ],
  [ "Dfx6q-tcR5s", "Get back to 3 Savile Row — first ever official Beatles fan experience. Opening 2027",
                                                                                         "Sign up at thebeatles.com/3savilerow" ],
  [ "fbAgp-qPpWs", "What a performance",                                                 "#TheBeatles #AllThingsMustPass #GeorgeHarrison" ]
]

videos.each_with_index do |(yid, title, description), i|
  next if Video.exists?(title: title)

  thumb_io = begin
    URI.open("https://img.youtube.com/vi/#{yid}/maxresdefault.jpg")
  rescue OpenURI::HTTPError
    URI.open("https://img.youtube.com/vi/#{yid}/hqdefault.jpg")
  end

  v = Video.new(
    title:       title,
    description: description,
    url:         "https://www.youtube.com/watch?v=#{yid}"
  )
  v.featured_image.attach(io: thumb_io, filename: "#{yid}.jpg", content_type: "image/jpeg")
  v.save!
  Story.find_or_create_by(storyable: v).update_columns(
    slug:         v.slug,
    is_published: true,
    published_at: (i + 6).days.ago,
    is_top:       false
  )
  puts "  video: #{title}"
end

puts "  done — #{Article.count} articles, #{Video.count} videos, #{Story.count} stories"
