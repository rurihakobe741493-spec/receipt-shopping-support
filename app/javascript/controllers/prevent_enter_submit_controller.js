import { Controller } from "@hotwired/stimulus"

// 文字の入力欄で Enter を押しても、フォームを送らない（確認・登録画面で、見直しの途中に登録されないため）
// 日本語の変換を確定する Enter は止めない
export default class extends Controller {
  prevent(event) {
    if (event.isComposing || event.keyCode === 229) return

    event.preventDefault()
  }
}
