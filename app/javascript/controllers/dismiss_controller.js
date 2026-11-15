import { Controller } from "@hotwired/stimulus"

// 知らせの箱を、×のボタンで閉じる（shared/_flash）。閉じるかどうかはユーザーに任せる（数秒で消す形にはしない）
// JavaScript が動かないときは閉じられないので、ボタンは初め hidden にしておき、ここで出す
export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.buttonTarget.hidden = false
  }

  close() {
    this.element.remove()
  }
}
