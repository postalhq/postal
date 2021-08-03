module Postal
  class SpamCheck

    attr_reader :code, :score, :description

    def initialize(code, score, description = nil)
      @code = code
      @score = score
      @description = description
    end

    def to_hash
      {
        code: code,
        score: score,
        description: description
      }
    end

  end
end
