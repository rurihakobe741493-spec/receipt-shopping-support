import { Controller } from "@hotwired/stimulus"

// 確認・登録画面で、既存のストックを選んだ行のうち、そのストックに購入日の欄と同じ日の購入記録がある行に、警告の文を出す
// 登録は止めない。警告の文はサーバーが行ごとに hidden で描いておき、ここでは hidden を出し入れするだけ
// チェックを外した行の警告は、CSS（group-has）で隠す。JavaScript が動かないときは、警告は出ない
export default class extends Controller {
  static targets = ["purchasedOn", "warning"]
  // ストックの id（文字列）ごとの購入日（"2026-09-27" の形）。ReceiptRegistrationForm#purchased_dates_by_item_id
  static values = { purchasedDates: Object }

  // 最初の表示と、登録できずに描き直したときにも判定する
  connect() {
    this.update()
  }

  // 購入日の欄と、各行の「ストック」が変わったときに、全部の行を判定し直す
  // （足した行も、判定のときに拾う。「選んでください」「新規として登録」は購入日の一覧にないので出ない）
  update() {
    const purchasedOn = this.purchasedOnTarget.value
    this.warningTargets.forEach((warning) => {
      const itemId = warning.closest("li").querySelector("select[name$='[item_id]']").value
      const dates = this.purchasedDatesValue[itemId] || []
      warning.hidden = !(purchasedOn && dates.includes(purchasedOn))
    })
  }
}
