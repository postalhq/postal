module HasUUID

  def self.included(base)
    base.class_eval do
      random_string :uuid, type: :uuid, unique: true
    end
  end

  def to_param
    uuid
  end

end
