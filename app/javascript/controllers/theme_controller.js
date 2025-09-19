import { Controller } from "@hotwired/stimulus"

// ThemeController: toggles between default (light) and ink (dark) themes.
// Persists selection in localStorage so preference survives reloads.
export default class extends Controller {
  static targets = ["icon"]

  connect() {
    const stored = window.localStorage.getItem("theme:ui")
    if (stored === "ink") {
      document.body.dataset.theme = "ink"
    } else {
      document.body.removeAttribute("data-theme")
    }
    this.updateIcon()
  }

  toggle() {
    const dark = document.body.dataset.theme === "ink"
    if (dark) {
      document.body.removeAttribute("data-theme")
      window.localStorage.setItem("theme:ui", "light")
    } else {
      document.body.dataset.theme = "ink"
      window.localStorage.setItem("theme:ui", "ink")
    }
    this.animateIcon()
    this.updateIcon()
  }

  updateIcon() {
    if (!this.hasIconTarget) return
    const dark = document.body.dataset.theme === "ink"
    this.iconTarget.classList.remove("fa-moon", "fa-sun")
    this.iconTarget.classList.add(dark ? "fa-sun" : "fa-moon")
  }

  animateIcon() {
    if (!this.hasIconTarget) return
    this.iconTarget.animate([
      { transform: 'scale(0.6) rotate(-40deg)', opacity: 0.3 },
      { transform: 'scale(1) rotate(0deg)', opacity: 1 }
    ], { duration: 300, easing: 'cubic-bezier(.4,.2,.2,1)' })
  }
}
