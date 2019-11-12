module Decorators
  class File

    attr_reader :file

    def initialize(file)
      @file = file
    end

    def to_h
      {
        message: 'created',
        id: file.id.to_s,
        name: file.name,
        type: file.mime_type
      }
    end

    def to_json
      to_h.to_json
    end
  end
end