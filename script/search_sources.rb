#!/usr/bin/env ruby
# frozen_string_literal: true

# script/search_sources.rb
#
# For each article in ~/Documents/edo-cms/content/articles/:
#   - Renames category "Automobiles" → "Mobility" in frontmatter
#   - Generates 3-5 tags via Claude API and writes them to frontmatter
#   - Searches Pexels + Flickr using those tags as query
#   - Searches YouTube (Japan-first if japan_related: true)
#
# Usage:
#   ruby script/search_sources.rb            # all articles
#   ruby script/search_sources.rb 1          # article matching prefix "1-"
#   ruby script/search_sources.rb honda      # article matching "honda" in folder name
#
# Required .env keys:
#   ANTHROPIC_API_KEY, PEXELS_API_KEY, FLICKR_API_KEY, YOUTUBE_API_KEY

require "net/http"
require "json"
require "open-uri"
require "yaml"
require "fileutils"
require "uri"

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

ARTICLES_DIR   = File.expand_path("~/Documents/edo-cms/content/articles")
PEXELS_IMAGES  = 5
FLICKR_IMAGES  = 5
YOUTUBE_VIDEOS = 3

FLICKR_LICENSE_NAMES = {
  "1" => "CC BY-NC-SA",
  "2" => "CC BY-NC",
  "3" => "CC BY-NC-ND",
  "4" => "CC BY",
  "5" => "CC BY-SA",
  "6" => "CC BY-ND",
  "9" => "CC0",
  "10" => "Public Domain"
}.freeze

# ---------------------------------------------------------------------------
# .env loader
# ---------------------------------------------------------------------------

def load_env
  env_path = File.join(__dir__, "../.env")
  return unless File.exist?(env_path)

  File.readlines(env_path).each do |line|
    line = line.strip
    next if line.empty? || line.start_with?("#")

    key, value = line.split("=", 2)
    ENV[key.strip] ||= value&.strip
  end
end

# ---------------------------------------------------------------------------
# HTTP helpers
# ---------------------------------------------------------------------------

def http_get(url, headers = {})
  uri = URI.parse(url)
  req = Net::HTTP::Get.new(uri)
  headers.each { |k, v| req[k] = v }

  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(req)
  end
end

def http_post(url, headers = {}, body = nil)
  uri = URI.parse(url)
  req = Net::HTTP::Post.new(uri)
  headers.each { |k, v| req[k] = v }
  req.body = body

  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(req)
  end
end

# ---------------------------------------------------------------------------
# Frontmatter helpers
# ---------------------------------------------------------------------------

def parse_frontmatter(md_path)
  content = File.read(md_path)
  match   = content.match(/\A---\s*\n(.*?)\n---/m)
  return {} unless match

  YAML.safe_load(match[1]) || {}
rescue StandardError
  {}
end

# Updates category + tags in article.md frontmatter in place.
# - Renames "Automobiles" → "Mobility" if present
# - Adds or replaces the `tags:` line
def update_article_frontmatter(md_path, tags)
  content = File.read(md_path)

  # Rename category
  content = content.gsub(/^(category:\s*["']?)Automobiles(["']?\s*)$/) { "#{$1}Mobility#{$2}" }

  tags_line = "tags: #{tags.inspect}"

  if content.match?(/^tags:/)
    content = content.gsub(/^tags:.*$/, tags_line)
  else
    # Insert after category line
    content = content.gsub(/^(category:.*)$/) { "#{$1}\ntags: #{tags.inspect}" }
  end

  File.write(md_path, content)
end

# ---------------------------------------------------------------------------
# Claude tag generation
# ---------------------------------------------------------------------------

def generate_tags(title, category, body_snippet)
  key = ENV["ANTHROPIC_API_KEY"]
  if key.nil? || key.empty?
    warn "  [tags] skipped — ANTHROPIC_API_KEY not set"
    return []
  end

  prompt = <<~PROMPT
    Generate 3 to 5 concise, relevant tags for this article.
    Rules:
    - Lowercase, single words or hyphenated (e.g. "mini-bike", "japan", "cycling")
    - Cover the main subject, style, and context
    - No generic tags like "article", "content", "interesting"
    - Return ONLY a comma-separated list, nothing else

    Title: #{title}
    Category: #{category}
    Content excerpt: #{body_snippet}
  PROMPT

  body = {
    model: "claude-haiku-4-5-20251001",
    max_tokens: 80,
    messages: [ { role: "user", content: prompt } ]
  }.to_json

  resp = http_post(
    "https://api.anthropic.com/v1/messages",
    {
      "x-api-key"         => key,
      "anthropic-version" => "2023-06-01",
      "content-type"      => "application/json"
    },
    body
  )

  data = JSON.parse(resp.body)
  if resp.code != "200"
    warn "  [tags] API error #{resp.code}: #{data.dig("error", "message")}"
    return []
  end

  text = data.dig("content", 0, "text").to_s.strip
  text.split(",").map(&:strip).reject(&:empty?).first(5)
rescue StandardError => e
  warn "  [tags] error: #{e.message}"
  []
end

# ---------------------------------------------------------------------------
# Pexels
# ---------------------------------------------------------------------------

def search_pexels(query, count)
  key = ENV["PEXELS_API_KEY"]
  if key.nil? || key.empty?
    warn "  [pexels] skipped — API key not set"
    return []
  end

  url  = "https://api.pexels.com/v1/search?query=#{URI.encode_www_form_component(query)}&per_page=#{count}&orientation=landscape"
  resp = http_get(url, "Authorization" => key)
  data = JSON.parse(resp.body)

  (data["photos"] || []).map do |p|
    {
      source:       "pexels",
      download_url: p.dig("src", "original"),
      photographer: p["photographer"],
      page_url:     p["url"],
      id:           p["id"].to_s,
      license:      "Pexels License"
    }
  end
rescue StandardError => e
  warn "  [pexels] error: #{e.message}"
  []
end

# ---------------------------------------------------------------------------
# Flickr
# ---------------------------------------------------------------------------

def search_flickr(query, count)
  key = ENV["FLICKR_API_KEY"]
  if key.nil? || key.empty?
    warn "  [flickr] skipped — API key not set"
    return []
  end

  params = URI.encode_www_form(
    method:        "flickr.photos.search",
    api_key:       key,
    text:          query,
    license:       "1,2,3,4,5,6,9,10",
    extras:        "url_l,url_c,url_m,owner_name,license,path_alias",
    per_page:      count,
    sort:          "relevance",
    format:        "json",
    nojsoncallback: 1
  )
  resp = http_get("https://www.flickr.com/services/rest/?#{params}")
  data = JSON.parse(resp.body)
  warn "  [flickr] HTTP #{resp.code} stat=#{data["stat"]} msg=#{data["message"]}" if data["stat"] != "ok"

  photos = data.dig("photos", "photo") || []
  warn "  [flickr] #{photos.size} result(s) found"

  photos.filter_map do |p|
    download_url = p["url_l"] || p["url_c"] || p["url_m"]
    unless download_url
      warn "  [flickr] no download URL for photo #{p["id"]} — owner may have restricted sizes"
      next
    end

    owner_path = p["path_alias"].to_s.empty? ? p["owner"] : p["path_alias"]
    {
      source:       "flickr",
      download_url: download_url,
      photographer: p["ownername"],
      page_url:     "https://www.flickr.com/photos/#{owner_path}/#{p["id"]}",
      id:           p["id"],
      license:      FLICKR_LICENSE_NAMES[p["license"].to_s] || "CC"
    }
  end
rescue StandardError => e
  warn "  [flickr] error: #{e.message}"
  []
end

# ---------------------------------------------------------------------------
# YouTube
# ---------------------------------------------------------------------------

def youtube_search_lang(query, lang, max, key)
  params = URI.encode_www_form(
    part:              "snippet",
    q:                 query,
    type:              "video",
    maxResults:        max,
    videoCaption:      "closedCaption",
    relevanceLanguage: lang,
    key:               key
  )
  resp = http_get("https://www.googleapis.com/youtube/v3/search?#{params}")
  data = JSON.parse(resp.body)
  warn "  [youtube/#{lang}] HTTP #{resp.code} — #{data["error"]&.dig("message")}" if resp.code != "200"

  (data["items"] || []).map do |item|
    {
      title:    item.dig("snippet", "title"),
      url:      "https://youtube.com/watch?v=#{item.dig("id", "videoId")}",
      language: lang
    }
  end
rescue StandardError => e
  warn "  [youtube/#{lang}] error: #{e.message}"
  []
end

def search_youtube(query, count, japan_related: false)
  key = ENV["YOUTUBE_API_KEY"]
  if key.nil? || key.empty?
    warn "  [youtube] skipped — API key not set"
    return []
  end

  if japan_related
    # Japan-related: 2 Japanese + 1 English
    ja = youtube_search_lang(query, "ja", 2, key)
    en = youtube_search_lang(query, "en", 1, key)
    (ja + en).uniq { |v| v[:url] }.first(count)
  else
    # Default: 2 English + 1 Japanese
    en = youtube_search_lang(query, "en", 2, key)
    ja = youtube_search_lang(query, "ja", 1, key)
    (en + ja).uniq { |v| v[:url] }.first(count)
  end
end

# ---------------------------------------------------------------------------
# Download image
# ---------------------------------------------------------------------------

def download_image(url, dest_path)
  URI.open(url, "rb") do |remote|  # rubocop:disable Security/Open
    File.binwrite(dest_path, remote.read)
  end
  true
rescue StandardError => e
  warn "  [download] #{File.basename(dest_path)}: #{e.message}"
  false
end

# ---------------------------------------------------------------------------
# Process one article
# ---------------------------------------------------------------------------

def process_article(folder)
  md_path = File.join(folder, "article.md")
  unless File.exist?(md_path)
    warn "  skipping — no article.md"
    return
  end

  front    = parse_frontmatter(md_path)
  title    = front["title"].to_s.strip
  if title.empty?
    warn "  skipping — no title in frontmatter"
    return
  end

  category     = front["category"].to_s.strip
  japan_related = front["japan_related"] == true

  # Rename category
  category = "Mobility" if category == "Automobiles"

  # Generate tags (skip if already present)
  existing_tags = front["tags"]
  if existing_tags.is_a?(Array) && !existing_tags.empty?
    tags = existing_tags
    puts "  tags (existing): #{tags.join(", ")}"
  else
    # Read article body for context (strip frontmatter, first 800 chars)
    raw_content  = File.read(md_path)
    body_snippet = raw_content.sub(/\A---.*?---\s*/m, "").gsub(/<!--.*?-->/m, "").strip.slice(0, 800)
    tags = generate_tags(title, category, body_snippet)
    if tags.empty?
      # Fallback: first 3 meaningful words from title
      stop_words = %w[a an the that which who of in on at to for is was are were and or but]
      query_clean = title.gsub(/[—–]/, " ").gsub(/[^\w\s]/, "").squeeze(" ").strip
      tags = query_clean.split.reject { |w| stop_words.include?(w.downcase) }.first(3)
    end
    puts "  tags (generated): #{tags.join(", ")}"
    update_article_frontmatter(md_path, tags)
  end

  # Build photo search query from tags
  photo_query = tags.join(" ")
  puts "  photo query: \"#{photo_query}\""
  puts "  japan_related: #{japan_related}"

  images_dir  = File.join(folder, "images_to_use")
  sources_dir = File.join(folder, "text-sources")
  FileUtils.mkdir_p(images_dir)
  FileUtils.mkdir_p(sources_dir)

  creds_path  = File.join(sources_dir, "images_creds.txt")
  videos_path = File.join(sources_dir, "video_urls.txt")

  File.write(creds_path, "")
  File.write(videos_path, "")

  # --- Images ---
  photos = search_pexels(photo_query, PEXELS_IMAGES) + search_flickr(photo_query, FLICKR_IMAGES)

  downloaded = 0
  photos.each_with_index do |photo, idx|
    ext      = File.extname(URI.parse(photo[:download_url]).path).downcase
    ext      = ".jpg" if ext.empty?
    filename = "#{photo[:source]}-#{idx + 1}-#{photo[:id]}#{ext}"
    dest     = File.join(images_dir, filename)

    if download_image(photo[:download_url], dest)
      downloaded += 1
      File.open(creds_path, "a") do |f|
        f.puts "#{filename} | #{photo[:photographer]} | #{photo[:page_url]} | #{photo[:license]}"
      end
    end
  end

  puts "  #{downloaded} image(s) downloaded"

  # --- Videos ---
  video_query = title.gsub(/[—–]/, " ").gsub(/[^\w\s]/, "").squeeze(" ").strip
  videos = search_youtube(video_query, YOUTUBE_VIDEOS, japan_related: japan_related)
  File.open(videos_path, "w") do |f|
    videos.each { |v| f.puts "#{v[:title]} | #{v[:url]}" }
  end
  puts "  #{videos.size} video URL(s) saved"
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

load_env

filter = ARGV[0]&.strip

folders = Dir.glob("#{ARTICLES_DIR}/*/").sort_by do |f|
  basename = File.basename(f)
  match    = basename.match(/\A(\d+)/)
  match ? [ 0, match[1].to_i, basename ] : [ 1, 0, basename ]
end

if filter
  folders = folders.select do |f|
    basename = File.basename(f)
    if filter.match?(/\A\d+\z/)
      basename.start_with?("#{filter}-")
    else
      basename.include?(filter)
    end
  end

  if folders.empty?
    abort "No article folder matching \"#{filter}\" found in #{ARTICLES_DIR}"
  end
end

puts "Processing #{folders.size} article(s)...\n\n"

folders.each_with_index do |folder, idx|
  basename = File.basename(folder)
  puts "[#{idx + 1}/#{folders.size}] #{basename}"
  process_article(folder)
  puts
  sleep 0.2 unless idx == folders.size - 1
end

puts "Done."
