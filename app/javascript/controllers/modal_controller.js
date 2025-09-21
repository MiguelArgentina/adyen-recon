import { Controller } from "@hotwired/stimulus"

// Controls native dialog modals for payout transaction details
export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    event.preventDefault()
    if (!this.hasDialogTarget) return

    const dialog = this.dialogTarget
    if (typeof dialog.showModal === "function") {
      dialog.showModal()
    } else {
      dialog.setAttribute("open", "open")
    }
  }

  close(event) {
    event.preventDefault()
    if (!this.hasDialogTarget) return

    const dialog = this.dialogTarget
    if (dialog.open) {
      dialog.close()
    } else {
      dialog.removeAttribute("open")
    }
  }

  backdrop(event) {
    if (!this.hasDialogTarget) return
    if (event.target !== event.currentTarget) return

    this.close(event)
  }
}
