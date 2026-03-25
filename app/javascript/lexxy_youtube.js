import { Extension, configure } from "lexxy"

const YOUTUBE_RE = /(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})/

function videoId(url) {
  try {
    const m = url.match(YOUTUBE_RE)
    return m ? m[1] : null
  } catch { return null }
}

function embedHtml(id) {
  return `<figure class="lexxy-youtube-embed" style="position:relative;width:100%;padding-bottom:56.25%;overflow:hidden;margin:1.5rem 0;">` +
    `<iframe src="https://www.youtube-nocookie.com/embed/${id}" ` +
    `title="YouTube video" frameborder="0" allowfullscreen loading="lazy" ` +
    `allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" ` +
    `style="position:absolute;inset:0;width:100%;height:100%;border:0;">` +
    `</iframe></figure>`
}

// Auto-embed when a YouTube URL is pasted
document.addEventListener("lexxy:insert-link", (event) => {
  const { url, replaceLinkWith } = event.detail
  const id = videoId(url)
  if (!id) return
  event.preventDefault()
  replaceLinkWith(embedHtml(id), { attachment: true })
})

// Toolbar button icon
const youtubeIcon = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="18" height="18"
  fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">
  <path d="M22.54 6.42a2.78 2.78 0 0 0-1.95-1.96C18.88 4 12 4 12 4s-6.88 0-8.59.46
    A2.78 2.78 0 0 0 1.46 6.42 29 29 0 0 0 1 12a29 29 0 0 0 .46 5.58
    2.78 2.78 0 0 0 1.95 1.96C5.12 20 12 20 12 20s6.88 0 8.59-.46
    a2.78 2.78 0 0 0 1.95-1.96A29 29 0 0 0 23 12a29 29 0 0 0-.46-5.58z"/>
  <polygon points="9.75 15.02 15.5 12 9.75 8.98 9.75 15.02"/>
</svg>`

// Toolbar extension — adds a YouTube button with URL dropdown
class YoutubeExtension extends Extension {
  initializeToolbar(toolbar) {
    const details = document.createElement("details")
    details.className = "lexxy-editor__toolbar-dropdown"

    const summary = document.createElement("summary")
    summary.className = "lexxy-editor__toolbar-button"
    summary.title = "Embed YouTube video"
    summary.innerHTML = youtubeIcon
    details.appendChild(summary)

    const content = document.createElement("div")
    content.className = "lexxy-editor__toolbar-dropdown-content"
    content.style.cssText = "min-width:260px;padding:0.5rem 0.75rem;"
    content.innerHTML = `
      <form style="display:flex;flex-direction:column;gap:0.5rem;">
        <input type="url" placeholder="https://youtube.com/watch?v=…"
               class="input" style="width:100%;" />
        <div class="lexxy-editor__toolbar-dropdown-actions">
          <button type="submit" class="lexxy-editor__toolbar-button"
                  style="padding:0.25rem 0.75rem;font-size:0.875rem;">Embed</button>
        </div>
      </form>
    `
    details.appendChild(content)

    content.querySelector("form").addEventListener("submit", (e) => {
      e.preventDefault()
      const url = content.querySelector("input").value.trim()
      if (!videoId(url)) return

      // Focus the contenteditable and simulate a URL paste so the
      // lexxy:insert-link listener above handles the embed insertion.
      const ce = this.editorElement.querySelector("[contenteditable]")
      if (ce) {
        ce.focus()
        const dt = new DataTransfer()
        dt.setData("text/plain", url)
        ce.dispatchEvent(new ClipboardEvent("paste", { clipboardData: dt, bubbles: true, cancelable: true }))
      }

      content.querySelector("input").value = ""
      details.removeAttribute("open")
    })

    // Insert before the overflow menu (last toolbar item)
    const overflow = toolbar.querySelector('[name="lexxy-dropdown"]')
    toolbar.insertBefore(details, overflow || null)
  }
}

configure({ global: { extensions: [YoutubeExtension] } })
