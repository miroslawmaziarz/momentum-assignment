require "rails_helper"

RSpec.describe Book do
  describe ".unused_serial_number" do
    it "passes over a serial number the library already holds" do
      create(:book, serial_number: "000001")
      allow(SecureRandom).to receive(:random_number).and_return(1, 1, 2)

      expect(described_class.unused_serial_number).to eq("000002")
    end

    it "pads a generated number to six digits" do
      allow(SecureRandom).to receive(:random_number).and_return(42)

      expect(described_class.unused_serial_number).to eq("000042")
    end

    it "gives up rather than looping forever when no number is free" do
      allow(SecureRandom).to receive(:random_number).and_return(1)
      create(:book, serial_number: "000001")

      expect { described_class.unused_serial_number }.to raise_error(/unused serial number/)
    end
  end
end
