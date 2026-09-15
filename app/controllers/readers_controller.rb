class ReadersController < ApplicationController
  def index
    render json: Reader.all.map { |reader| ReaderSerializer.new(reader) }
  end

  def show
    render json: ReaderSerializer.new(Reader.find_by_card_number!(params[:card_number]))
  end

  def create
    reader = Reader.new(reader_params)
    reader.save!

    render json: ReaderSerializer.new(reader), status: :created
  rescue ActiveRecord::RecordNotUnique
    reader.validate
    reader.errors.add(:base, :taken) if reader.errors.empty?

    raise ActiveRecord::RecordInvalid, reader
  end

  private

  def reader_params
    params.require(:reader).permit(:card_number, :full_name, :email)
  end
end
