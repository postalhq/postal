module ActionView
  module RecordIdentifier

    def dom_id(record, prefix = nil)
      if record.new_record?
        dom_class(record, prefix || NEW)
      else
        id = record.respond_to?(:uuid) ? record.uuid : record.id
        "#{dom_class(record, prefix)}#{JOIN}#{id}"
      end
    end

  end
end
