# script/prepare_articles.rb
#
# Enriches article.md frontmatter with fields required by the Rails Article model,
# then finds-or-creates the Article record in the DB and attaches images from
# images_to_use/ as photo_candidates.
#
# Usage:
#   bin/rails runner script/prepare_articles.rb           # all articles
#   bin/rails runner script/prepare_articles.rb 1         # by folder number prefix
#   bin/rails runner script/prepare_articles.rb honda     # by folder name fragment

require "yaml"
require "pathname"

CONTENT_DIR     = Pathname.new("/Users/jeromesadou/Documents/sepiabraun/content/articles")
DEFAULT_AUTHOR_ID    = 1
DEFAULT_READING_TIME = 5
IMAGE_GLOB      = "*.{jpg,jpeg,png,webp,gif,JPG,JPEG,PNG}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def parse_frontmatter(raw)
  parts = raw.split(/^---\s*$/, 3)
  # parts[0] is empty (text before first ---), parts[1] is YAML, parts[2] is body
  return [{}, raw] unless parts.length == 3

  fm   = YAML.safe_load(parts[1]) || {}
  body = parts[2]
  [fm, body]
end

def write_frontmatter(fm, body)
  yaml = YAML.dump(fm).sub(/\A---\n/, "") # YAML.dump prepends "---\n", remove it
  "---\n#{yaml}---\n#{body}"
end

def derive_subtitle(title)
  if title.include?(" — ")
    title.split(" — ", 2).last.strip.capitalize
  elsif title.include?(" - ")
    title.split(" - ", 2).last.strip.capitalize
  else
    title
  end
end

def set_unless_present(fm, key, value)
  return false if fm.key?(key) && !fm[key].nil? && fm[key].to_s.strip != ""
  fm[key] = value
  true
end

# ---------------------------------------------------------------------------
# Load DB lookups once
# ---------------------------------------------------------------------------

cats_by_name = Category.not_deleted.index_by { |c| c.name.downcase.strip }
fallback_category_id = Category.not_deleted.first&.id

# ---------------------------------------------------------------------------
# Determine which article folders to process
# ---------------------------------------------------------------------------

filter = ARGV.first

all_dirs = Dir.glob(CONTENT_DIR.join("*")).select { |d| File.directory?(d) }.sort

dirs = if filter
  all_dirs.select do |d|
    name = File.basename(d)
    name.start_with?(filter) || name.include?(filter)
  end
else
  all_dirs
end

if dirs.empty?
  puts "No article folders matched '#{filter}'"
  exit 1
end

puts "Processing #{dirs.length} article(s)...\n\n"

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

dirs.each do |dir|
  folder_name = File.basename(dir)
  md_path     = File.join(dir, "article.md")

  unless File.exist?(md_path)
    puts "  SKIP #{folder_name} — no article.md"
    next
  end

  begin
    raw    = File.read(md_path)
    fm, body = parse_frontmatter(raw)

    title = fm["title"].to_s.strip
    if title.empty?
      puts "  SKIP #{folder_name} — no title in frontmatter"
      next
    end

    changes  = []
    subtitle = fm["subtitle"].to_s.strip.presence || derive_subtitle(title)

    # --- Resolve category ---
    cat_name   = fm["category"].to_s.downcase.strip
    category   = cats_by_name[cat_name]
    category_id = category&.id || fallback_category_id

    # --- Fill missing fields ---
    if set_unless_present(fm, "author_id", DEFAULT_AUTHOR_ID)
      changes << "author_id"
    end

    if set_unless_present(fm, "subtitle", subtitle)
      changes << "subtitle"
    else
      subtitle = fm["subtitle"] # use existing value downstream
    end

    if set_unless_present(fm, "category_id", category_id)
      changes << "category_id=#{category_id}"
    end

    if set_unless_present(fm, "status", "draft")
      changes << "status"
    end

    if set_unless_present(fm, "reading_time", DEFAULT_READING_TIME)
      changes << "reading_time"
    end

    # published_at — ensure key exists with nil value so it's explicit
    unless fm.key?("published_at")
      fm["published_at"] = nil
      changes << "published_at"
    end

    if set_unless_present(fm, "excerpt", subtitle)
      changes << "excerpt"
    end

    if set_unless_present(fm, "meta_description", subtitle)
      changes << "meta_description"
    end

    tags = Array(fm["tags"])
    if set_unless_present(fm, "meta_keywords", tags.join(", "))
      changes << "meta_keywords"
    end

    # --- Write back if changed ---
    if changes.any?
      File.write(md_path, write_frontmatter(fm, body))
    end

    # --- Find or create Article in DB ---
    # Try slug first (more reliable than exact title match across import variants)
    derived_slug = title.parameterize
    article = Article.find_by(slug: derived_slug)
    article ||= Article.find_by(title: title)

    if article.nil?
      article = Article.new(
        title:            title,
        subtitle:         fm["subtitle"],
        excerpt:          fm["excerpt"],
        meta_description: fm["meta_description"],
        meta_keywords:    fm["meta_keywords"],
        reading_time:     fm["reading_time"] || DEFAULT_READING_TIME,
        status:           :draft,
        author_id:        DEFAULT_AUTHOR_ID,
        category_id:      fm["category_id"] || fallback_category_id
      )
      article.save(validate: false)  # content is intentionally blank at this stage
      db_action = "created"
    else
      # Fill in any fields missing in DB (idempotent, skip content validation)
      article.assign_attributes(
        subtitle:         article.subtitle.presence         || fm["subtitle"],
        excerpt:          article.excerpt.presence          || fm["excerpt"],
        meta_description: article.meta_description.presence || fm["meta_description"],
        meta_keywords:    article.meta_keywords.presence    || fm["meta_keywords"],
        reading_time:     article.reading_time              || DEFAULT_READING_TIME,
        author_id:        article.author_id                 || DEFAULT_AUTHOR_ID,
        category_id:      article.category_id               || fallback_category_id
      )
      article.save(validate: false)
      db_action = "updated"
    end

    # --- Attach photos (idempotent: skip if already has candidates) ---
    photo_count = 0
    images_dir  = File.join(dir, "images_to_use")

    if Dir.exist?(images_dir) && !article.photo_candidates.attached?
      image_paths = Dir.glob(File.join(images_dir, IMAGE_GLOB))
      image_paths.each do |img_path|
        content_type = Marcel::MimeType.for(Pathname.new(img_path))
        article.photo_candidates.attach(
          io:           File.open(img_path, "rb"),
          filename:     File.basename(img_path),
          content_type: content_type
        )
        photo_count += 1
      end
      # Rails 8: attachment records are deferred until parent is saved
      article.save(validate: false) if photo_count > 0
    elsif article.photo_candidates.attached?
      photo_count = article.photo_candidates.count
    end

    fm_summary  = changes.any? ? "md: +#{changes.join(', ')}" : "md: no changes"
    photo_label = photo_count > 0 ? "#{photo_count} photo(s)" : "no photos"
    puts "  ✓ #{folder_name}"
    puts "    #{fm_summary} | DB #{db_action} | #{photo_label}"

  rescue => e
    puts "  ✗ #{folder_name} — ERROR: #{e.message}"
    puts "    #{e.backtrace.first}"
  end
end

puts "\nDone."
