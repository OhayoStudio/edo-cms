// app/javascript/controllers/video_player_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "mainContainer", 
    "mainThumbnail", 
    "videoFrame", 
    "mainTitle", 
    "mainDescription", 
    "mainPlayButton", // Added target for main play button
    "thumbnailPlayButton" // Added target for thumbnail play buttons
  ]

  connect() {
    // Initialize any required setup
    this.currentVideoId = this.mainThumbnailTarget.dataset.videoId
  }

  playMainVideo(event) {
    const videoId = event.currentTarget.dataset.videoId
    this.loadVideo(videoId)

    // Hide the main play button
    this.mainPlayButtonTarget.classList.add('hidden')
  }

  switchVideo(event) {
    event.preventDefault()
    const videoId = event.currentTarget.dataset.videoId
    const title = event.currentTarget.dataset.videoTitle
    const description = event.currentTarget.dataset.videoDescription
    const thumbnail = event.currentTarget.dataset.videoThumbnail
    
    // Update main video section
    this.mainTitleTarget.textContent = title
    this.mainDescriptionTarget.textContent = description
    
    // Show the main thumbnail with updated content before playing
    this.mainThumbnailTarget.src = thumbnail
    this.mainThumbnailTarget.dataset.videoId = videoId
    this.currentVideoId = videoId

    // Show the play button again for the new video
    this.mainPlayButtonTarget.classList.remove('hidden')

    // If a video is already playing, load the new one directly
    if (!this.videoFrameTarget.classList.contains('hidden')) {
      this.loadVideo(videoId)
    }
  }
  
  loadVideo(videoId) {
    // Create and load the YouTube iframe
    this.videoFrameTarget.innerHTML = `
      <iframe 
        src="https://www.youtube.com/embed/${videoId}?autoplay=1" 
        frameborder="0" 
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" 
        allowfullscreen
        class="w-full h-full">
      </iframe>
    `
    
    // Hide thumbnail, show video
    this.mainThumbnailTarget.classList.add('hidden')
    this.videoFrameTarget.classList.remove('hidden')
    
    // Hide the play button
    this.mainPlayButtonTarget.classList.add('hidden')

    // Update current video ID
    this.currentVideoId = videoId
  }
}