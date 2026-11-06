require "rails_helper"
require "google/cloud/errors"

RSpec.describe ReceiptOcrService do
  # Vision API の代わりのクライアント（batch_annotate_images の応答を決める）
  def stub_client
    client = double("Vision API のクライアント")
    allow(Google::Cloud::Vision).to receive(:image_annotator).and_return(client)
    client
  end

  # 画像1枚分の応答（error と full_text_annotation だけを持つ）
  def annotate_response(text: nil, error_message: nil)
    error = error_message && double("エラー", message: error_message)
    annotation = text && double("全文", text:)
    double("応答", responses: [ double("画像1枚分の応答", error:, full_text_annotation: annotation) ])
  end

  def image
    StringIO.new("画像の中身")
  end

  describe ".call" do
    it "読み取った全文を返し、画像の中身と検出の種類を送る" do
      client = stub_client
      allow(client).to receive(:batch_annotate_images).and_return(annotate_response(text: "読み取った全文"))

      expect(described_class.call(image)).to eq("読み取った全文")
      expect(client).to have_received(:batch_annotate_images).with(
        requests: [ { image: { content: "画像の中身" }, features: [ { type: :DOCUMENT_TEXT_DETECTION } ] } ]
      )
    end

    it "文字が見つからなければ、空の文字列を返す" do
      allow(stub_client).to receive(:batch_annotate_images).and_return(annotate_response)

      expect(described_class.call(image)).to eq("")
    end

    it "認証の鍵がなければ、Vision API に送らずに ReceiptOcrService::Error にする" do
      allow(Rails.application).to receive(:credentials).and_return(ActiveSupport::OrderedOptions.new)
      # 鍵を読むのは、クライアントを作るときのブロックの中なので、本物の入り口を通す
      allow(Google::Cloud::Vision).to receive(:image_annotator).and_call_original

      expect { described_class.call(image) }.to raise_error(ReceiptOcrService::Error, "Cloud Vision の認証情報がありません")
    end

    it "画像1枚分の応答にエラーがあれば、その説明で ReceiptOcrService::Error にする" do
      allow(stub_client).to receive(:batch_annotate_images).and_return(annotate_response(error_message: "Bad image data."))

      expect { described_class.call(image) }.to raise_error(ReceiptOcrService::Error, "Bad image data.")
    end

    it "通信などで Google の例外が起きたら、その説明で ReceiptOcrService::Error にする" do
      allow(stub_client).to receive(:batch_annotate_images).and_raise(Google::Cloud::UnavailableError, "接続できません")

      expect { described_class.call(image) }.to raise_error(ReceiptOcrService::Error, "接続できません")
    end
  end
end
