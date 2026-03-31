#!/usr/bin/env ruby
# frozen_string_literal: true

# script/search_sources.rb
#
# Searches Pexels and Flickr for images, and YouTube for video URLs,
# for each article in ~/Documents/edo-cms/content/articles/.
#
# Usage:
#   ruby script/search_sources.rb            # all articles
#   ruby script/search_sources.rb 1          # article matching prefix "1-"
#   ruby script/search_sources.rb honda      # article matching "honda" in folder name
#
# Required .env keys:
#   PEXELS_API_KEY, FLICKR_API_KEY, GOOGLE_API_KEY

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
# HTTP helper
# ---------------------------------------------------------------------------

def http_get(url, headers = {})
  uri = URI.parse(url)
  req = Net::HTTP::Get.new(uri)
  headers.each { |k, v| req[k] = v }

  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(req)
  end
end

# ---------------------------------------------------------------------------
# Frontmatter parser
# ---------------------------------------------------------------------------

def parse_frontmatter(md_path)
  content = File.read(md_path)
  match   = content.match(/\A---\s*\n(.*?)\n---/m)
  return {} unless match

  YAML.safe_load(match[1]) || {}
rescue StandardError
  {}
end

# ---------------------------------------------------------------------------
# Pexels
# ---------------------------------------------------------------------------

def search_pexels(query, count)
  key = ENV["PEXELS_API_KEY"]
  return [] if key.nil? || key.empty?

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
  return [] if key.nil? || key.empty?

  params = URI.encode_www_form(
    method:        "flickr.photos.search",
    api_key:       key,
    text:          query,
    license:       "1,2,3,4,5,6,9,10",
    extras:        "url_l,url_c,owner_name,license,path_alias",
    per_page:      count,
    sort:          "relevance",
    format:        "json",
    nojsoncallback: 1
  )
  resp = http_get("https://www.flickr.com/services/rest/?#{params}")
  data = JSON.parse(resp.body)

  (data.dig("photos", "photo") || []).filter_map do |p|
    download_url = p["url_l"] || p["url_c"]
    next unless download_url

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

def search_youtube(query, count)
  key = ENV["GOOGLE_API_KEY"]
  return [] if key.nil? || key.empty?

  params = URI.encode_www_form(
    part:       "snippet",
    q:          query,
    type:       "video",
    maxResults: count,
    key:        key
  )
  resp = http_get("https://www.googleapis.com/youtube/v3/search?#{params}")
  data = JSON.parse(resp.body)

  (data["items"] || []).map do |item|
    {
      title: item.dig("snippet", "title"),
      url:   "https://youtube.com/watch?v=#{item.dig("id", "videoId")}"
    }
  end
rescue StandardError => e
  warn "  [youtube] error: #{e.message}"
  []
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

  front   = parse_frontmatter(md_path)
  title   = front["title"].to_s.strip
  if title.empty?
    warn "  skipping — no title in frontmatter"
    return
  end

  images_dir   = File.join(folder, "images_to_use")
  sources_dir  = File.join(folder, "text-sources")
  FileUtils.mkdir_p(images_dir)
  FileUtils.mkdir_p(sources_dir)

  creds_path  = File.join(sources_dir, "images_creds.txt")
  videos_path = File.join(sources_dir, "video_urls.txt")

  # Clear existing output files for this run
  File.write(creds_path, "")
  File.write(videos_path, "")

  puts "  query: \"#{title}\""

  # --- Images ---
  photos = search_pexels(title, PEXELS_IMAGES) + search_flickr(title, FLICKR_IMAGES)

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
  videos = search_youtube(title, YOUTUBE_VIDEOS)
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
  # Sort numerically by leading digits, then alphabetically
  basename = File.basename(f)
  match    = basename.match(/\A(\d+)/)
  match ? [ 0, match[1].to_i, basename ] : [ 1, 0, basename ]
end

if filter
  folders = folders.select do |f|
    basename = File.basename(f)
    basename.start_with?("#{filter}-") || basename.include?(filter)
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
