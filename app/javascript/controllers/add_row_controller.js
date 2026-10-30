import { Controller } from "@hotwired/stimulus"

// 確認・登録画面で、読み取れなかった品目の行を足す
// <template> の中の行（番号の目印は NEW_ROW）を写し、目印を足した時刻の数字に置き換えて、一覧の最後に足す
// JavaScript が動かないときは足せないので、ボタンは初め hidden にしておき、ここで出す
export default class extends Controller {
  static targets = ["list", "template", "button"]

  connect() {
    this.buttonTarget.hidden = false
  }

  add() {
    // 番号は数字だけにする（数字でない番号の行は、登録のコントローラーの params.expect で捨てられるため）
    const html = this.templateTarget.innerHTML.replaceAll("NEW_ROW", Date.now().toString())
    this.listTarget.insertAdjacentHTML("beforeend", html)
    // 足した行のレシート表記の欄にカーソルを移す（すぐ打ち始められるように）
    this.listTarget.lastElementChild.querySelector("input[name$='[receipt_name]']").focus()
  }
}
