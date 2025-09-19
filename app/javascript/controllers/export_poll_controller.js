import { Controller } from "@hotwired/stimulus"

// export-poll controller: polls the export show endpoint until status is generated or failed.
export default class extends Controller {
  static values = { status: String, exportId: Number }
  static targets = [ ]

  connect() {
    this.interval = null
    this.startPollingIfNeeded()
    document.addEventListener('visibilitychange', this.handleVisibility)
  }

  disconnect() {
    this.stop()
    document.removeEventListener('visibilitychange', this.handleVisibility)
  }

  handleVisibility = () => {
    if (document.hidden) {
      this.stop()
    } else {
      this.startPollingIfNeeded(true)
    }
  }

  startPollingIfNeeded(force = false) {
    const st = this.statusValue
    if (!force && (st === 'generated' || st === 'failed')) return
    this.stop()
    this.interval = setInterval(() => this.poll(), 3000)
  }

  poll() {
    fetch(window.location.href, { headers: { 'Turbo-Frame': 'poll', 'Accept': 'text/vnd.turbo-stream.html,text/html,application/xhtml+xml' }})
      .then(r => r.text())
      .then(html => {
        // Parse the status out of the current DOM again (simpler: reload the page via Turbo)
        if (window.Turbo) {
          Turbo.visit(window.location.href, { action: 'replace' })
        } else {
          window.location.reload()
        }
      })
      .catch(() => this.stop())
  }

  stop() {
    if (this.interval) {
      clearInterval(this.interval)
      this.interval = null
    }
  }
}

