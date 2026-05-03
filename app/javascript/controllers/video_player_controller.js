import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "mainContainer",
    "mainThumbnail",
    "videoFrame",
    "mainTitle",
    "mainDescription",
    "mainPlayButton",
    "thumbnailPlayButton"
  ]

  connect() {
    this.currentVideoId = this.mainThumbnailTarget.dataset.videoId
  }

  playMainVideo(event) {
    this.loadVideo(event.currentTarget.dataset.videoId)
    this.mainPlayButtonTarget.classList.add('hidden')
  }

  switchVideo(event) {
    event.preventDefault()
    const el = event.currentTarget

    if (window.innerWidth < 768) {
      this._playInline(el)
    } else {
      this._swapToMain(el)
    }
  }

  _playInline(el) {
    const videoId = el.dataset.videoId
    const frame = el.querySelector('[data-inline-frame]')
    if (!frame) return

    // Close any other open inline players first
    this.element.querySelectorAll('[data-inline-frame]').forEach(f => {
      if (f !== frame) {
        f.innerHTML = ''
        f.classList.add('hidden')
        const thumb = f.closest('[data-action]')?.querySelector('img')
        if (thumb) thumb.classList.remove('hidden')
        const btn = f.closest('[data-action]')?.querySelector('[data-video-player-target="thumbnailPlayButton"]')
        if (btn) btn.classList.remove('hidden')
      }
    })

    const thumb = el.querySelector('img')
    const playBtn = el.querySelector('[data-video-player-target="thumbnailPlayButton"]')

    frame.innerHTML = `
      <iframe
        src="https://www.youtube.com/embed/${videoId}?autoplay=1"
        frameborder="0"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
        allowfullscreen
        class="w-full h-full">
      </iframe>
    `
    frame.classList.remove('hidden')
    if (thumb) thumb.classList.add('hidden')
    if (playBtn) playBtn.classList.add('hidden')
  }

  _swapToMain(el) {
    const wasPlaying = !this.videoFrameTarget.classList.contains('hidden')

    // Snapshot the current main
    const oldMain = {
      videoId:     this.mainThumbnailTarget.dataset.videoId,
      title:       this.mainTitleTarget.textContent.trim(),
      description: this.mainDescriptionTarget.textContent.trim(),
      thumbnail:   this.mainThumbnailTarget.src
    }

    // Promote clicked secondary to main
    const newMain = {
      videoId:     el.dataset.videoId,
      title:       el.dataset.videoTitle,
      description: el.dataset.videoDescription,
      thumbnail:   el.dataset.videoThumbnail
    }

    this.mainTitleTarget.textContent         = newMain.title
    this.mainDescriptionTarget.textContent   = newMain.description
    this.mainThumbnailTarget.src             = newMain.thumbnail
    this.mainThumbnailTarget.dataset.videoId = newMain.videoId
    this.currentVideoId = newMain.videoId

    // Move old main into the vacated secondary slot
    el.dataset.videoId          = oldMain.videoId
    el.dataset.videoTitle       = oldMain.title
    el.dataset.videoDescription = oldMain.description
    el.dataset.videoThumbnail   = oldMain.thumbnail

    const img = el.querySelector('img')
    if (img) img.src = oldMain.thumbnail

    const h4 = el.querySelector('h4')
    if (h4) h4.textContent = oldMain.title

    const p = el.querySelector('p')
    if (p) p.textContent = oldMain.description.substring(0, 110)

    if (wasPlaying) {
      this.loadVideo(newMain.videoId)
    } else {
      this.videoFrameTarget.innerHTML = ''
      this.videoFrameTarget.classList.add('hidden')
      this.mainThumbnailTarget.classList.remove('hidden')
      this.mainPlayButtonTarget.classList.remove('hidden')
    }
  }

  loadVideo(videoId) {
    this.videoFrameTarget.innerHTML = `
      <iframe
        src="https://www.youtube.com/embed/${videoId}?autoplay=1"
        frameborder="0"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
        allowfullscreen
        class="w-full h-full">
      </iframe>
    `
    this.mainThumbnailTarget.classList.add('hidden')
    this.videoFrameTarget.classList.remove('hidden')
    this.mainPlayButtonTarget.classList.add('hidden')
    this.currentVideoId = videoId
  }
}
