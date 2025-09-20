import { Controller } from "@hotwired/stimulus"

// Handles UI affordances for multi-file uploads.
export default class extends Controller {
  static targets = ["status"]

  submitStart(event) {
    const input = this.element.querySelector('input[type="file"]')
    if (!input) return

    const count = input.files ? input.files.length : 0
    if (count > 0) {
      this.showSpinner(count)
    } else {
      this.reset()
    }
  }

  submitEnd(event) {
    if (event.detail?.success) {
      // Successful submissions navigate away; let Turbo replace the view.
      return
    }
    this.reset()
  }

  showSpinner(count) {
    if (!this.hasStatusTarget) return

    const label = count === 1 ? "file" : "files"
    this.statusTarget.innerHTML = `
      <div class="flex items-center gap-2 text-sm text-[color:var(--text-muted)]">
        <span class="inline-block h-4 w-4 border-2 border-current border-t-transparent rounded-full animate-spin" aria-hidden="true"></span>
        <span>Uploading ${count} ${label}…</span>
      </div>
    `
    this.statusTarget.classList.remove("hidden")
  }

  reset() {
    if (!this.hasStatusTarget) return
    this.statusTarget.innerHTML = ""
    this.statusTarget.classList.add("hidden")
  }
}
