require "rails_helper"

RSpec.describe ReceiptScanForm do
  # コントローラーに届くときと同じ形の画像（中身は "a" を並べたもの）
  def uploaded_image(type: "image/jpeg", bytes: 10)
    ActionDispatch::Http::UploadedFile.new(tempfile: StringIO.new("a" * bytes), type:, filename: "receipt.jpg")
  end

  def scan_form(image)
    ReceiptScanForm.new(image:).tap(&:validate)
  end

  it "JPEG・PNG・WEBP の画像なら、エラーにしない" do
    %w[image/jpeg image/png image/webp].each do |type|
      expect(scan_form(uploaded_image(type:)).errors).to be_empty, type
    end
  end

  it "画像がなければ、no_image のエラーにし、画像を選ぶ文を出す" do
    form = scan_form(nil)

    expect(form.errors.of_kind?(:image, :no_image)).to be(true)
    expect(form.errors.first.message).to eq("画像を選んでください。")
  end

  it "届いたものが画像のファイルでなければ（文字列など）、no_image のエラーにする" do
    expect(scan_form("receipt.jpg").errors.of_kind?(:image, :no_image)).to be(true)
  end

  it "JPEG・PNG・WEBP でなければ、invalid_type のエラーにする" do
    expect(scan_form(uploaded_image(type: "text/plain")).errors.of_kind?(:image, :invalid_type)).to be(true)
  end

  it "ちょうど 7MB なら、エラーにしない" do
    expect(scan_form(uploaded_image(bytes: 7.megabytes)).errors).to be_empty
  end

  it "7MB を1バイトでも超えると、too_large のエラーにし、上限の MB を入れた文を出す" do
    form = scan_form(uploaded_image(bytes: 7.megabytes + 1))

    expect(form.errors.of_kind?(:image, :too_large)).to be(true)
    expect(form.errors.first.message).to eq("画像が大きすぎます（7MBまで）。")
  end

  it "種類も大きさも外れていれば、先に確かめる種類のエラーだけにする" do
    form = scan_form(uploaded_image(type: "text/plain", bytes: 7.megabytes + 1))

    expect(form.errors.map(&:type)).to eq([ :invalid_type ])
  end
end
