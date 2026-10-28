import { Controller } from "@hotwired/stimulus"

// 描かれたときに、この要素の位置まで画面を動かす
// （確認・登録画面で、下のボタンのあたりから送ってエラーになったとき、上の知らせに気づけるように）
export default class extends Controller {
  connect() {
    this.element.scrollIntoView({ block: "start" })
  }
}
